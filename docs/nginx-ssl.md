# 🌐 Configure NGINX with SSL for n8n

These optional steps let you serve n8n through HTTPS using a custom domain name.
You should already have n8n running via Docker on port **5678** (the default after deployment).

---

## 1. Point your domain

1. In your DNS provider, create an **A record** pointing your domain (e.g. `n8n.example.com`) to your VM's public IP.
2. Wait for the DNS change to propagate, then check that it returns **your VM's IP** before continuing
   (Certbot fails if it points anywhere else):

```bash
dig +short n8n.example.com
```

---

## 2. Open ports 80 and 443 on the VM

The Terraform security list already allows 80 and 443, but OCI Ubuntu images also ship
with host firewall rules that only allow SSH. Open the two ports on the VM:

```bash
sudo iptables -I INPUT 1 -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -I INPUT 1 -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT
sudo netfilter-persistent save
```

---

## 3. Install NGINX and Certbot

Connect to your instance via SSH and install the packages:

```bash
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx -y
```

Enable NGINX at boot:

```bash
sudo systemctl enable nginx --now
```

---

## 4. Create a reverse proxy config

Create `/etc/nginx/sites-available/n8n` with the following content
(replace `n8n.example.com` with your domain):

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    listen [::]:80;
    server_name n8n.example.com;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Using the real `server_name` (instead of a catch-all `default_server`) means requests
that reach the VM by IP or with another hostname are not forwarded to n8n.

Activate the configuration and test:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

You should now reach n8n via `http://n8n.example.com`.

---

## 5. Obtain a Let's Encrypt certificate

Run Certbot to request an SSL certificate and let it update the NGINX config
(it also adds the HTTP → HTTPS redirect):

```bash
sudo certbot --nginx -d n8n.example.com --redirect
```

Certbot will configure HTTPS and set up automatic renewal.
You can test renewal with:

```bash
sudo certbot renew --dry-run
```

---

## 6. Update n8n settings for HTTPS

Edit `docker-compose.yml` (in `/root` after the automatic deployment, so run `sudo -i` first) and change the `n8n` service. Replace the `ports` entry and **add** the new variables to the existing `environment:` list:

```yaml
    ports:
      - "127.0.0.1:5678:5678"   # only NGINX can reach n8n now
    environment:
      - N8N_HOST=n8n.example.com
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.example.com/
      - N8N_PROXY_HOPS=1
```

Also **delete** the `N8N_SECURE_COOKIE=false` line. It was only there to allow logins
over plain HTTP; once removed, the session cookie is marked `Secure`.

Binding to `127.0.0.1` matters: Docker publishes ports directly and bypasses the host
firewall rules, so `"5678:5678"` would keep serving n8n over plain HTTP next to your HTTPS site.

Recreate the container after editing:

```bash
cd /root && docker compose up -d
```

Your instance is now secured with HTTPS via NGINX. You can now connect to `https://n8n.example.com`.

---

## 7. Optional hardening

- You no longer need port **5678** in the OCI security list; you can remove that rule from
  `terraform/main.tf` (or the VCN security list in the console).
- Keep SSH restricted to your own IP (the `allowed_cidr` Terraform variable).
- To upgrade n8n, change the pinned image tag in `docker-compose.yml`, then, as root in `/root`, run
  `docker compose pull && docker compose up -d`. Check the
  [n8n security advisories](https://github.com/n8n-io/n8n/security/advisories) regularly.

# 🚀 Deploy n8n on Oracle Cloud Free Tier

This guide helps you deploy [n8n](https://n8n.io) for free on Oracle Cloud using the Always Free Tier with an ARM-based VM.
You don’t need a domain name or SSL, but both can be added optionally for production use.

> **Production note**
> For a secure setup, it is highly recommended to run n8n behind an NGINX reverse proxy with HTTPS enabled. This protects the login cookie and other traffic. See [docs/nginx-ssl.md](docs/nginx-ssl.md) for instructions.

---

## 📦 Requirements

- A free Oracle Cloud account → [Sign up](https://www.oracle.com/cloud/free/)
- A private SSH key to access your VM
- Your public IP address (for the `allowed_cidr` setting below)
- Use of the **Always Free Tier** (ARM): VM.Standard.A1.Flex with:
  - 1 OCPU
  - 4 GB RAM
  - 50 GB block storage

When creating your Oracle Cloud account, you must provide a valid credit card for identity verification. You won't be charged as long as you stay within the Always Free tier.

This project uses the `VM.Standard.A1.Flex` instance type, which is part of the Always Free tier with the following limits:
- **4 OCPUs**
- **24 GB RAM**
- **2 VMs max per tenancy**

n8n will run comfortably within those limits.

---

## ☁️ Deploy to Oracle Cloud

You can use the button below to provision the instance and network infrastructure:

[![Deploy to Oracle Cloud](https://github.com/clementalo9/oke_A1/raw/main/images/Deploy2OCI.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/clementalo9/n8n_oci/archive/refs/heads/main.zip)

Terraform provisions the VM, installs Docker, and installs a pinned n8n version automatically via
[`scripts/install_n8n.sh`](scripts/install_n8n.sh).

When the stack form asks for **Allowed IP range (CIDR)**, enter your own public IP followed by `/32`
(for example `203.0.113.10/32`). Only that range can reach SSH and the n8n editor; `0.0.0.0/0` is rejected.

> **Deploying your own changes**
> The button above deploys the upstream repository's `main` branch. If you modify this repo, either change the
> `zipUrl` to point at your own fork, upload a zip of the repo to Resource Manager, or run `terraform apply`
> from the `terraform/` folder.

## 🔌 Ports Opened by Terraform

The Terraform stack creates a security list that allows inbound traffic on the following ports:

- **22** – SSH access to administer the VM (only from `allowed_cidr`).
- **80** – HTTP traffic, required if you plan to run a reverse proxy or obtain certificates with Certbot.
- **443** – HTTPS traffic once you configure SSL for n8n.
- **5678** – The n8n editor listens on this port (only from `allowed_cidr`).

You can review these rules in [`terraform/main.tf`](terraform/main.tf) inside the `oci_core_security_list` resource.

Once deployment completes, continue below to access your n8n editor.

If you want to connect via SSH to you VM, use the default **ubuntu** user and provide the private key you used during stack creation:

```bash
ssh -i /path/to/private/key ubuntu@YOUR_PUBLIC_IP
```

---

## 🌐 Access Your n8n Editor

- Go to your browser and open:

```
 http://YOUR_PUBLIC_IP:5678/setup
```

> On first run, connecting to `http://YOUR_PUBLIC_IP:5678/setup` lets you create the n8n owner account.
> Do this right after deployment: whoever opens `/setup` first owns the instance. n8n has built-in user
> management (the old `N8N_BASIC_AUTH_*` variables were removed in n8n 1.0), so no password is baked into the deployment.
>
> **Note:** During automatic deployment the script changes to the root user's home directory, so `docker-compose.yml` and the `n8n_data/` folder will be inside `/root`.

---

## 🔒 Optional: Enable HTTPS with a Custom Domain Name

By default, n8n is accessible via:

```
http://YOUR_PUBLIC_IP:5678
```

This works without a domain name or reverse proxy, but traffic (including your login) is unencrypted.
For security reasons, I strongly recommend HTTPS (domain name required) behind NGINX.

See [`docs/nginx-ssl.md`](docs/nginx-ssl.md) for help with domain, NGINX setup, and HTTPS.

---

## 🛡️ Security checklist

- Keep `allowed_cidr` as narrow as possible and never `0.0.0.0/0`.
- Create the n8n owner account immediately after the first boot, and enable 2FA in the n8n user settings.
- Move to HTTPS and bind n8n to `127.0.0.1` as described in [docs/nginx-ssl.md](docs/nginx-ssl.md).
- n8n is pinned to a specific version in `scripts/install_n8n.sh` and `docker-compose.yml`. Update it regularly
  and watch the [n8n security advisories](https://github.com/n8n-io/n8n/security/advisories).
- Only give workflow-editing access to people you trust: workflows can run code and reach the VM's network.
- Back up `n8n_data/`: it holds your workflows and the encryption key for stored credentials.

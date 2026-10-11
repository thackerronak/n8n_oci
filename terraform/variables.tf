variable "tenancy_ocid" {
  description = "OCID of Oracle Cloud Tenancy"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR allowed to reach SSH (22) and the n8n editor (5678), e.g. 203.0.113.10/32. Ports 80/443 stay open to the internet for HTTPS and webhooks."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0))
    error_message = "allowed_cidr must be a valid CIDR block, e.g. 203.0.113.10/32."
  }

  validation {
    condition     = var.allowed_cidr != "0.0.0.0/0"
    error_message = "allowed_cidr must not be 0.0.0.0/0: that exposes SSH and the unauthenticated n8n /setup page to the whole internet."
  }
}

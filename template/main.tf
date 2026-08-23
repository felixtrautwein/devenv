terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.60.1"
    }
  }

  backend "s3" {
    bucket   = "dummy"
    key      = "dummy"
    region = "nbg1"
    access_key = "dummy"
    secret_key = "dummy"
    endpoint = "https://nbg1.your-objectstorage.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id = true
    use_path_style = true
    skip_s3_checksum = true
  }
}

provider "hcloud" {
  token = var.hetzner_api_key
}

variable "hetzner_api_key" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type = string
}

variable "k8s_ingress_ipv4" {
  type        = string
  description = "Public IPv4 address of the Kubernetes ingress controller/load balancer"
}

resource "hcloud_zone_rrset" "root" {
  zone    = var.domain_name
  name    = "@"
  type    = "A"
  records = [{ value = var.k8s_ingress_ipv4 }]
}

resource "hcloud_zone_rrset" "www_root" {
  zone    = var.domain_name
  name    = "www"
  type    = "CNAME"
  records = [{ value = format("%s.", var.domain_name) }]
}

# --- repository specific Terraform additions below ---

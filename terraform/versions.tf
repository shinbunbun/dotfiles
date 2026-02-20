terraform {
  required_version = ">= 1.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2025.12"
    }
  }
}

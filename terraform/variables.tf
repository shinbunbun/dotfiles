# Cloudflare API認証情報
variable "cloudflare_api_token" {
  description = "Cloudflare API Token (Terraform実行時に環境変数から取得)"
  type        = string
  sensitive   = true
}

# Cloudflare Zone ID
variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for shinbunbun.com"
  type        = string
}

# Cloudflare Account ID
variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

# トンネルID (既存のトンネルを参照)
variable "home_tunnel_id" {
  description = "Cloudflare Tunnel ID for home-services"
  type        = string
}

variable "desktop_tunnel_id" {
  description = "Cloudflare Tunnel ID for desktop-services"
  type        = string
}

# 認証プロバイダー設定
variable "identity_provider_id" {
  description = "Identity Provider ID for Cloudflare Access (Authentikなど)"
  type        = string
}

# OIDC認証設定
variable "oidc_claim_name" {
  description = "OIDC claim name for group-based authentication"
  type        = string
  default     = "groups"
}

variable "oidc_claim_value" {
  description = "OIDC claim value (group name) for access control"
  type        = string
  default     = "Cloudflare Access"
}

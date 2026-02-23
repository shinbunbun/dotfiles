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

# --- Authentik ---
variable "authentik_api_token" {
  description = "Authentik API Token"
  type        = string
  sensitive   = true
}

variable "authentik_url" {
  description = "Authentik API URL"
  type        = string
  default     = "https://auth.shinbunbun.com"
}

# 各プロバイダーのclient_id/secretはSOPSから注入
variable "grafana_oauth_client_id" {
  description = "Grafana OAuth2 Client ID"
  type        = string
  sensitive   = true
}

variable "grafana_oauth_client_secret" {
  description = "Grafana OAuth2 Client Secret"
  type        = string
  sensitive   = true
}

variable "cloudflare_oidc_client_id" {
  description = "Cloudflare OIDC Client ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_oidc_client_secret" {
  description = "Cloudflare OIDC Client Secret"
  type        = string
  sensitive   = true
}

variable "couchdb_oauth_client_id" {
  description = "CouchDB (shinbunbun-home-idp) OAuth2 Client ID"
  type        = string
  sensitive   = true
}

variable "couchdb_oauth_client_secret" {
  description = "CouchDB (shinbunbun-home-idp) OAuth2 Client Secret"
  type        = string
  sensitive   = true
}

variable "opensearch_oauth_client_id" {
  description = "OpenSearch Dashboards OAuth2 Client ID"
  type        = string
  sensitive   = true
}

variable "opensearch_oauth_client_secret" {
  description = "OpenSearch Dashboards OAuth2 Client Secret"
  type        = string
  sensitive   = true
}

variable "argocd_oauth_client_id" {
  description = "ArgoCD OAuth2 Client ID"
  type        = string
  sensitive   = true
}

variable "argocd_oauth_client_secret" {
  description = "ArgoCD OAuth2 Client Secret"
  type        = string
  sensitive   = true
}

/*
  Authentik プロバイダー定義

  OAuth2プロバイダーとProxyプロバイダーを管理する。
  client_id/client_secretはSOPSから環境変数経由で注入する。
*/

# --- OAuth2 Providers ---

# CouchDB用（Obsidian LiveSync等）
resource "authentik_provider_oauth2" "couchdb" {
  name               = "shinbunbun-home-idp"
  authorization_flow = data.authentik_flow.default_authorization_explicit_consent.id
  invalidation_flow  = data.authentik_flow.default_provider_invalidation.id
  client_type        = "confidential"
  client_id          = var.couchdb_oauth_client_id
  client_secret      = var.couchdb_oauth_client_secret
  signing_key        = data.authentik_certificate_key_pair.es256_jwt_signing.id
  allowed_redirect_uris = [
    { matching_mode = "strict", url = "http://localhost:8080/callback" }
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  sub_mode                  = "hashed_user_id"
  issuer_mode               = "per_provider"
  include_claims_in_id_token = true
  access_code_validity      = "minutes=1"
  access_token_validity     = "minutes=5"
  refresh_token_validity    = "days=30"
  lifecycle {
    ignore_changes = [logout_method, refresh_token_threshold]
  }
}

# Cloudflare Zero Trust OIDC
resource "authentik_provider_oauth2" "cloudflare_zero_trust" {
  name               = "Cloudflare Zero Trust"
  authorization_flow = data.authentik_flow.default_authorization_explicit_consent.id
  invalidation_flow  = data.authentik_flow.default_provider_invalidation.id
  client_type        = "confidential"
  client_id          = var.cloudflare_oidc_client_id
  client_secret      = var.cloudflare_oidc_client_secret
  signing_key        = data.authentik_certificate_key_pair.es256_jwt_signing.id
  allowed_redirect_uris = [
    { matching_mode = "strict", url = "https://shinbunbun.cloudflareaccess.com/cdn-cgi/access/callback" }
  ]
  property_mappings = [
    authentik_property_mapping_provider_scope.oidc_groups.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  sub_mode                  = "hashed_user_id"
  issuer_mode               = "per_provider"
  include_claims_in_id_token = true
  access_code_validity      = "minutes=1"
  access_token_validity     = "minutes=5"
  refresh_token_validity    = "days=30"
  lifecycle {
    ignore_changes = [logout_method, refresh_token_threshold]
  }
}

# Grafana OAuth2
resource "authentik_provider_oauth2" "grafana" {
  name               = "Grafana"
  authorization_flow = data.authentik_flow.default_authorization_explicit_consent.id
  invalidation_flow  = data.authentik_flow.default_provider_invalidation.id
  client_type        = "confidential"
  client_id          = var.grafana_oauth_client_id
  client_secret      = var.grafana_oauth_client_secret
  signing_key        = data.authentik_certificate_key_pair.es256_jwt_signing.id
  allowed_redirect_uris = [
    { matching_mode = "strict", url = "https://grafana.shinbunbun.com/login/generic_oauth" }
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  sub_mode                  = "hashed_user_id"
  issuer_mode               = "per_provider"
  include_claims_in_id_token = true
  access_code_validity      = "minutes=1"
  access_token_validity     = "minutes=5"
  refresh_token_validity    = "days=30"
  lifecycle {
    ignore_changes = [logout_method, refresh_token_threshold]
  }
}

# OpenSearch Dashboards OAuth2
resource "authentik_provider_oauth2" "opensearch_dashboards" {
  name               = "OpenSearch Dashboards"
  authorization_flow = data.authentik_flow.default_authorization_implicit_consent.id
  invalidation_flow  = data.authentik_flow.default_provider_invalidation.id
  client_type        = "confidential"
  client_id          = var.opensearch_oauth_client_id
  client_secret      = var.opensearch_oauth_client_secret
  allowed_redirect_uris = [
    { matching_mode = "strict", url = "https://opensearch.shinbunbun.com/auth/openid/login" }
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  sub_mode                  = "hashed_user_id"
  issuer_mode               = "per_provider"
  include_claims_in_id_token = true
  access_code_validity      = "minutes=1"
  access_token_validity     = "minutes=5"
  refresh_token_validity    = "days=30"
  lifecycle {
    ignore_changes = [logout_method, refresh_token_threshold]
  }
}

# ArgoCD OAuth2
resource "authentik_provider_oauth2" "argocd" {
  name               = "ArgoCD"
  authorization_flow = data.authentik_flow.default_authorization_implicit_consent.id
  invalidation_flow  = data.authentik_flow.default_provider_invalidation.id
  client_type        = "confidential"
  client_id          = var.argocd_oauth_client_id
  client_secret      = var.argocd_oauth_client_secret
  signing_key        = data.authentik_certificate_key_pair.es256_jwt_signing.id
  allowed_redirect_uris = [
    { matching_mode = "strict", url = "https://argocd.shinbunbun.com/auth/callback" }
  ]
  property_mappings = [
    authentik_property_mapping_provider_scope.oidc_groups.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]
  sub_mode                   = "hashed_user_id"
  issuer_mode                = "per_provider"
  include_claims_in_id_token = true
  access_code_validity       = "minutes=1"
  access_token_validity      = "minutes=5"
  refresh_token_validity     = "days=30"
  lifecycle {
    ignore_changes = [logout_method, refresh_token_threshold]
  }
}

# --- Proxy Provider ---

# wg-lease Proxy Provider（Embedded Outpost経由）
resource "authentik_provider_proxy" "wg_lease" {
  name               = "wg-lease-proxy"
  authorization_flow = data.authentik_flow.default_authorization_implicit_consent.id
  invalidation_flow  = data.authentik_flow.default_provider_invalidation.id
  internal_host      = "http://192.168.1.3:8088"
  external_host      = "https://wg-lease.shinbunbun.com"
  mode               = "proxy"
  property_mappings = [
    authentik_property_mapping_provider_scope.oidc_groups.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.proxy.id,
  ]
  access_token_validity      = "hours=24"
  refresh_token_validity     = "days=30"
  internal_host_ssl_validation = true
  intercept_header_auth      = true
  jwks_sources = [
    authentik_source_oauth.github_actions_oidc.id,
  ]
}

# ========================================
# CloudFlare Zero Trust Access Applications
# ========================================
#
# ========================================
# home-services (homeMachine) Access Applications
# ========================================

# Grafana - 認証必須
resource "cloudflare_zero_trust_access_application" "grafana" {
  account_id                = var.cloudflare_account_id
  name                      = "Grafana"
  domain                    = local.home_services.grafana
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
    precedence = 1
  }]
}

# Cockpit (homeMachine) - 認証必須
resource "cloudflare_zero_trust_access_application" "home_cockpit" {
  account_id                = var.cloudflare_account_id
  name                      = "Cockpit"
  domain                    = local.home_services.cockpit
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
    precedence = 1
  }]
}

# ttyd Terminal (homeMachine) - 認証必須
resource "cloudflare_zero_trust_access_application" "home_ttyd" {
  account_id                = var.cloudflare_account_id
  name                      = "Terminal"
  domain                    = local.home_services.ttyd
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
    precedence = 1
  }]
}

# ========================================
# desktop-services (nixos-desktop) Access Applications
# ========================================

# Cockpit (nixos-desktop) - 認証必須
resource "cloudflare_zero_trust_access_application" "desktop_cockpit" {
  account_id                = var.cloudflare_account_id
  name                      = "Desktop Cockpit"
  domain                    = local.desktop_services.cockpit
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
    precedence = 1
  }]
}

# ttyd Terminal (nixos-desktop) - 認証必須
resource "cloudflare_zero_trust_access_application" "desktop_ttyd" {
  account_id                = var.cloudflare_account_id
  name                      = "Desktop Terminal"
  domain                    = local.desktop_services.ttyd
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
    precedence = 1
  }]
}

# ArgoCD - 認証必須
resource "cloudflare_zero_trust_access_application" "argocd" {
  account_id                = var.cloudflare_account_id
  name                      = "ArgoCD"
  domain                    = local.desktop_services.argocd
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
    precedence = 1
  }]
}

# OpenSearch Dashboards - 認証必須
resource "cloudflare_zero_trust_access_application" "opensearch_dashboards" {
  account_id                = var.cloudflare_account_id
  name                      = "OpenSearch Dashboards"
  domain                    = local.desktop_services.opensearch_dashboards
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
    precedence = 1
  }]
}


# ========================================
# CloudFlare Zero Trust Access Policies
# ========================================
# 全ApplicationでOIDC認証Policyを共有
# ========================================

# 共有Policy: OIDC groups claim認証
resource "cloudflare_zero_trust_access_policy" "oidc_groups_allow" {
  account_id = var.cloudflare_account_id
  name       = "CloudFlare Groups Access"
  decision   = "allow"

  include = [{
    oidc = {
      identity_provider_id = var.identity_provider_id
      claim_name           = var.oidc_claim_name
      claim_value          = var.oidc_claim_value
    }
  }]
}

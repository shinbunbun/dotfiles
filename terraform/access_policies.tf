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

# Nextcloud: CloudFlare Access Applicationなし
# Nextcloud自体がuser_oidc (Authentik SSO)で認証するため、
# CloudFlare Accessの事前認証は不要。
# モバイルアプリからの接続を可能にするため意図的に削除 (Issue #538)

# Immich - ブラウザはOIDC認証、モバイルアプリはService Token認証
resource "cloudflare_zero_trust_access_application" "immich" {
  account_id                = var.cloudflare_account_id
  name                      = "Immich"
  domain                    = local.desktop_services.immich
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
  allowed_idps              = [var.identity_provider_id]
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.oidc_groups_allow.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.immich_service_auth.id
      precedence = 2
    },
  ]
}

# Service Token（Immichモバイルアプリ用）
resource "cloudflare_zero_trust_access_service_token" "immich_mobile" {
  account_id = var.cloudflare_account_id
  name       = "Immich Mobile App"
  duration   = "8760h"
}

# Service Auth Policy（Service Tokenでのアクセスを許可）
resource "cloudflare_zero_trust_access_policy" "immich_service_auth" {
  account_id = var.cloudflare_account_id
  name       = "Immich Service Auth"
  decision   = "non_identity"

  include = [{
    service_token = {
      token_id = cloudflare_zero_trust_access_service_token.immich_mobile.id
    }
  }]
}

# Google Calendar Bot - 認証必須
resource "cloudflare_zero_trust_access_application" "calendar_bot" {
  account_id                = var.cloudflare_account_id
  name                      = "Google Calendar Bot"
  domain                    = local.desktop_services.calendar_bot
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

# mixi2 Bot - Webhook受信のため全体バイパス
resource "cloudflare_zero_trust_access_application" "mixi2_bot" {
  account_id                = var.cloudflare_account_id
  name                      = "mixi2 Bot"
  domain                    = local.desktop_services.mixi2_bot
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.webhook_bypass.id
    precedence = 1
  }]
}

# Google Calendar Bot Webhook - 認証バイパス（Google Push通知受信用）
resource "cloudflare_zero_trust_access_application" "calendar_bot_webhook" {
  account_id                = var.cloudflare_account_id
  name                      = "Google Calendar Bot Webhook"
  domain                    = "${local.desktop_services.calendar_bot}/api/webhook/calendar"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
  enable_binding_cookie     = false
  options_preflight_bypass  = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.webhook_bypass.id
    precedence = 1
  }]
}


# ========================================
# CloudFlare Zero Trust Access Policies
# ========================================
# 全ApplicationでOIDC認証Policyを共有
# ========================================

# 共有Policy: Webhookバイパス（認証不要な外部連携パス用）
resource "cloudflare_zero_trust_access_policy" "webhook_bypass" {
  account_id = var.cloudflare_account_id
  name       = "Webhook Bypass"
  decision   = "bypass"

  include = [{
    everyone = {}
  }]
}

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

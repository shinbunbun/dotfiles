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

# Hubble UI - 認証必須（Hubble UI 自体は認証なしのため Cloudflare Access で保護）
resource "cloudflare_zero_trust_access_application" "hubble" {
  account_id                = var.cloudflare_account_id
  name                      = "Hubble"
  domain                    = local.home_services.hubble
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

# Scanopy - 認証必須（Scanopy UI は Authentik OIDC 連携予定だが二重防御として Cloudflare Access でも保護）
resource "cloudflare_zero_trust_access_application" "scanopy" {
  account_id                = var.cloudflare_account_id
  name                      = "Scanopy"
  domain                    = local.home_services.scanopy
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

# Open WebUI - 認証必須（OpenWebUI 自体も Authentik OIDC 連携するが二重防御として Cloudflare Access でも保護）
resource "cloudflare_zero_trust_access_application" "openwebui" {
  account_id                = var.cloudflare_account_id
  name                      = "Open WebUI"
  domain                    = local.home_services.openwebui
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

# Argo Workflows - 認証必須 (argocd と同パターン、Cloudflare Access 前段 + argo-server SSO 後段の二重)
resource "cloudflare_zero_trust_access_application" "argo_workflows" {
  account_id                = var.cloudflare_account_id
  name                      = "Argo Workflows"
  domain                    = local.desktop_services.argo_workflows
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

# Terrakube UI/API - 認証必須 (dotfiles-private#327)
# 単一ホスト terrakube.shinbunbun.com の / (UI) と /api (ブラウザ SPA→API) を
# Authentik groups で保護。/dex は下の bypass app (より具体的な path) が優先する。
resource "cloudflare_zero_trust_access_application" "terrakube" {
  account_id                = var.cloudflare_account_id
  name                      = "Terrakube"
  domain                    = local.home_services.terrakube
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

# Terrakube Dex - 認証バイパス
# Terrakube api がトークン検証で Dex の JWKS を …/dex/keys から取得する
# (サーバ間=Cookie 無し) ため、/dex を CF Access で塞ぐとログインが壊れる。
# Dex 自体は OIDC provider なので公開前提で許容。path 指定で UI app より優先。
resource "cloudflare_zero_trust_access_application" "terrakube_dex" {
  account_id                = var.cloudflare_account_id
  name                      = "Terrakube Dex"
  domain                    = "${local.home_services.terrakube}/dex"
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

/*
  Authentik アプリケーション定義

  各プロバイダーに紐付くアプリケーションを管理する。
*/

resource "authentik_application" "couchdb" {
  name               = "CouchDB"
  slug               = "couchdb"
  protocol_provider  = authentik_provider_oauth2.couchdb.id
  policy_engine_mode = "any"
}

resource "authentik_application" "cloudflare_zero_trust" {
  name               = "Cloudflare Zero Trust"
  slug               = "cloudflare-zero-trust"
  protocol_provider  = authentik_provider_oauth2.cloudflare_zero_trust.id
  meta_launch_url    = "https://shinbunbun.cloudflareaccess.com/cdn-cgi/access/login/cloudflare-zero-trust"
  policy_engine_mode = "any"
}

resource "authentik_application" "grafana" {
  name               = "Grafana"
  slug               = "grafana"
  protocol_provider  = authentik_provider_oauth2.grafana.id
  meta_launch_url    = "https://grafana.shinbunbun.com"
  policy_engine_mode = "any"
}

resource "authentik_application" "argocd" {
  name               = "ArgoCD"
  slug               = "argocd"
  protocol_provider  = authentik_provider_oauth2.argocd.id
  meta_launch_url    = "https://argocd.shinbunbun.com"
  policy_engine_mode = "any"
}

# slug は argo-server SSO の issuer URL 末尾と一致必須:
# https://auth.shinbunbun.com/application/o/argo-workflows/
resource "authentik_application" "argo_workflows" {
  name               = "Argo Workflows"
  slug               = "argo-workflows"
  protocol_provider  = authentik_provider_oauth2.argo_workflows.id
  meta_launch_url    = "https://${local.desktop_services.argo_workflows}"
  policy_engine_mode = "any"
}

resource "authentik_application" "nextcloud" {
  name               = "Nextcloud"
  slug               = "nextcloud"
  protocol_provider  = authentik_provider_oauth2.nextcloud.id
  meta_launch_url    = "https://nextcloud.shinbunbun.com"
  policy_engine_mode = "any"
}

resource "authentik_application" "immich" {
  name               = "Immich"
  slug               = "immich"
  protocol_provider  = authentik_provider_oauth2.immich.id
  policy_engine_mode = "any"
}

resource "authentik_application" "wg_lease" {
  name               = "wg-lease"
  slug               = "wg-lease"
  protocol_provider  = authentik_provider_proxy.wg_lease.id
  policy_engine_mode = "any"
}

resource "authentik_application" "scanopy" {
  name               = "Scanopy"
  slug               = "scanopy"
  protocol_provider  = authentik_provider_oauth2.scanopy.id
  meta_launch_url    = "https://scanopy.shinbunbun.com"
  policy_engine_mode = "any"
}

resource "authentik_application" "librechat" {
  name               = "LibreChat"
  slug               = "librechat"
  protocol_provider  = authentik_provider_oauth2.librechat.id
  meta_launch_url    = "https://chat.shinbunbun.com"
  policy_engine_mode = "any"
}

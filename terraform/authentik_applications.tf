/*
  Authentik アプリケーション定義

  各プロバイダーに紐付くアプリケーションを管理する。
*/

resource "authentik_application" "couchdb" {
  name              = "CouchDB"
  slug              = "couchdb"
  protocol_provider = authentik_provider_oauth2.couchdb.id
  policy_engine_mode = "any"
}

resource "authentik_application" "cloudflare_zero_trust" {
  name              = "Cloudflare Zero Trust"
  slug              = "cloudflare-zero-trust"
  protocol_provider = authentik_provider_oauth2.cloudflare_zero_trust.id
  meta_launch_url   = "https://shinbunbun.cloudflareaccess.com/cdn-cgi/access/login/cloudflare-zero-trust"
  policy_engine_mode = "any"
}

resource "authentik_application" "grafana" {
  name              = "Grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana.id
  meta_launch_url   = "https://grafana.shinbunbun.com"
  policy_engine_mode = "any"
}

resource "authentik_application" "opensearch_dashboards" {
  name              = "OpenSearch Dashboards"
  slug              = "opensearch-dashboards"
  protocol_provider = authentik_provider_oauth2.opensearch_dashboards.id
  meta_launch_url   = "https://opensearch.shinbunbun.com"
  policy_engine_mode = "any"
}

resource "authentik_application" "argocd" {
  name               = "ArgoCD"
  slug               = "argocd"
  protocol_provider  = authentik_provider_oauth2.argocd.id
  meta_launch_url    = "https://argocd.shinbunbun.com"
  policy_engine_mode = "any"
}

resource "authentik_application" "wg_lease" {
  name              = "wg-lease"
  slug              = "wg-lease"
  protocol_provider = authentik_provider_proxy.wg_lease.id
  policy_engine_mode = "any"
}

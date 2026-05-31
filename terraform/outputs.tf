# Access Application IDs
output "access_application_ids" {
  description = "Cloudflare Access Application IDs"
  value = {
    # home-services
    grafana      = cloudflare_zero_trust_access_application.grafana.id
    home_cockpit = cloudflare_zero_trust_access_application.home_cockpit.id
    # desktop-services
    desktop_cockpit      = cloudflare_zero_trust_access_application.desktop_cockpit.id
    argocd               = cloudflare_zero_trust_access_application.argocd.id
    argo_workflows       = cloudflare_zero_trust_access_application.argo_workflows.id
    calendar_bot         = cloudflare_zero_trust_access_application.calendar_bot.id
    calendar_bot_webhook = cloudflare_zero_trust_access_application.calendar_bot_webhook.id
    immich               = cloudflare_zero_trust_access_application.immich.id
  }
}

# Immichモバイルアプリ用Service Token
output "immich_mobile_service_token_client_id" {
  description = "Immich Mobile App - CF-Access-Client-Id"
  value       = cloudflare_zero_trust_access_service_token.immich_mobile.client_id
  sensitive   = true
}

output "immich_mobile_service_token_client_secret" {
  description = "Immich Mobile App - CF-Access-Client-Secret（初回のみ表示）"
  value       = cloudflare_zero_trust_access_service_token.immich_mobile.client_secret
  sensitive   = true
}

# DNSレコード情報
output "dns_records" {
  description = "Created DNS records"
  value = {
    # home-services
    authentik         = cloudflare_dns_record.authentik.name
    grafana           = cloudflare_dns_record.grafana.name
    obsidian_livesync = cloudflare_dns_record.obsidian_livesync.name
    home_cockpit      = cloudflare_dns_record.home_cockpit.name
    # desktop-services
    desktop_cockpit = cloudflare_dns_record.desktop_cockpit.name
    argocd          = cloudflare_dns_record.argocd.name
    argo_workflows  = cloudflare_dns_record.argo_workflows.name
  }
}

# Tunnel エンドポイント
output "tunnel_endpoints" {
  description = "Cloudflare Tunnel endpoints"
  value = {
    home_services    = local.home_tunnel_endpoint
    desktop_services = local.desktop_tunnel_endpoint
  }
}

# Authentik Applications
output "authentik_applications" {
  description = "Authentik Application slugs"
  value = {
    couchdb               = authentik_application.couchdb.slug
    cloudflare_zero_trust = authentik_application.cloudflare_zero_trust.slug
    grafana               = authentik_application.grafana.slug
    wg_lease              = authentik_application.wg_lease.slug
    argocd                = authentik_application.argocd.slug
    argo_workflows        = authentik_application.argo_workflows.slug
  }
}

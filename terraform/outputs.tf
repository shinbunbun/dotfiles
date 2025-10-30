# Access Application IDs
output "access_application_ids" {
  description = "Cloudflare Access Application IDs"
  value = {
    # home-services
    grafana      = cloudflare_zero_trust_access_application.grafana.id
    home_cockpit = cloudflare_zero_trust_access_application.home_cockpit.id
    home_ttyd    = cloudflare_zero_trust_access_application.home_ttyd.id
    # desktop-services
    desktop_cockpit       = cloudflare_zero_trust_access_application.desktop_cockpit.id
    desktop_ttyd          = cloudflare_zero_trust_access_application.desktop_ttyd.id
    opensearch_dashboards = cloudflare_zero_trust_access_application.opensearch_dashboards.id
  }
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
    home_ttyd         = cloudflare_dns_record.home_ttyd.name
    # desktop-services
    desktop_cockpit       = cloudflare_dns_record.desktop_cockpit.name
    desktop_ttyd          = cloudflare_dns_record.desktop_ttyd.name
    opensearch_dashboards = cloudflare_dns_record.opensearch_dashboards.name
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

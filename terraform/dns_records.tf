# ========================================
# home-services (homeMachine) DNSレコード
# ========================================

# Authentik
resource "cloudflare_dns_record" "authentik" {
  zone_id = var.cloudflare_zone_id
  name    = "auth.${local.base_domain}"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Authentik (IdP) via home-services tunnel"
}

# Grafana
resource "cloudflare_dns_record" "grafana" {
  zone_id = var.cloudflare_zone_id
  name    = "grafana.${local.base_domain}"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Grafana via home-services tunnel"
}

# Obsidian LiveSync
resource "cloudflare_dns_record" "obsidian_livesync" {
  zone_id = var.cloudflare_zone_id
  name    = "private-obsidian.${local.base_domain}"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Obsidian LiveSync via home-services tunnel"
}

# Cockpit (homeMachine)
resource "cloudflare_dns_record" "home_cockpit" {
  zone_id = var.cloudflare_zone_id
  name    = "cockpit.${local.base_domain}"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Cockpit (Home) via home-services tunnel"
}

# Attic Binary Cache
resource "cloudflare_dns_record" "attic" {
  zone_id = var.cloudflare_zone_id
  name    = "cache.${local.base_domain}"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Attic Binary Cache via home-services tunnel"
}

# peer-issuer (WireGuard peer動的発行API) - Authentik outpost経由で認証
resource "cloudflare_dns_record" "peer_issuer" {
  zone_id = var.cloudflare_zone_id
  name    = "wg-lease.${local.base_domain}"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - peer-issuer via home-services tunnel"
}

# SSH for CI/CD deployment
resource "cloudflare_dns_record" "deploy_ssh" {
  zone_id = var.cloudflare_zone_id
  name    = "ssh.${local.base_domain}"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - SSH for deploy-rs via home-services tunnel"
}

# ========================================
# desktop-services (nixos-desktop) DNSレコード
# ========================================

# Cockpit (nixos-desktop)
resource "cloudflare_dns_record" "desktop_cockpit" {
  zone_id = var.cloudflare_zone_id
  name    = "desktop-cockpit.${local.base_domain}"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Cockpit (Desktop) via desktop-services tunnel"
}

# OpenSearch Dashboards
resource "cloudflare_dns_record" "opensearch_dashboards" {
  zone_id = var.cloudflare_zone_id
  name    = "opensearch.${local.base_domain}"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - OpenSearch Dashboards via desktop-services tunnel"
}

# ArgoCD
resource "cloudflare_dns_record" "argocd" {
  zone_id = var.cloudflare_zone_id
  name    = "argocd.${local.base_domain}"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - ArgoCD via desktop-services tunnel"
}

# Google Calendar Bot
resource "cloudflare_dns_record" "calendar_bot" {
  zone_id = var.cloudflare_zone_id
  name    = "calendar-bot.${local.base_domain}"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Google Calendar Bot via desktop-services tunnel"
}

# Nextcloud
resource "cloudflare_dns_record" "nextcloud" {
  zone_id = var.cloudflare_zone_id
  name    = "nextcloud.${local.base_domain}"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Nextcloud via desktop-services tunnel"
}

# Immich
resource "cloudflare_dns_record" "immich" {
  zone_id = var.cloudflare_zone_id
  name    = "immich.${local.base_domain}"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Immich via desktop-services tunnel"
}

# mixi2 Bot
resource "cloudflare_dns_record" "mixi2_bot" {
  zone_id = var.cloudflare_zone_id
  name    = "mixi2-bot.${local.base_domain}"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - mixi2 Bot via desktop-services tunnel"
}

# ========================================
# home-services (homeMachine) DNSレコード
# ========================================

# Authentik
resource "cloudflare_dns_record" "authentik" {
  zone_id = var.cloudflare_zone_id
  name    = "auth"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Authentik (IdP) via home-services tunnel"
}

# Grafana
resource "cloudflare_dns_record" "grafana" {
  zone_id = var.cloudflare_zone_id
  name    = "grafana"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Grafana via home-services tunnel"
}

# Obsidian LiveSync
resource "cloudflare_dns_record" "obsidian_livesync" {
  zone_id = var.cloudflare_zone_id
  name    = "private-obsidian"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Obsidian LiveSync via home-services tunnel"
}

# Cockpit (homeMachine)
resource "cloudflare_dns_record" "home_cockpit" {
  zone_id = var.cloudflare_zone_id
  name    = "cockpit"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Cockpit (Home) via home-services tunnel"
}

# ttyd Terminal (homeMachine)
resource "cloudflare_dns_record" "home_ttyd" {
  zone_id = var.cloudflare_zone_id
  name    = "terminal"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Terminal (Home) via home-services tunnel"
}

# Attic Binary Cache
resource "cloudflare_dns_record" "attic" {
  zone_id = var.cloudflare_zone_id
  name    = "cache"
  content = local.home_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Attic Binary Cache via home-services tunnel"
}

# SSH for CI/CD deployment
resource "cloudflare_dns_record" "deploy_ssh" {
  zone_id = var.cloudflare_zone_id
  name    = "ssh"
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
  name    = "desktop-cockpit"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Cockpit (Desktop) via desktop-services tunnel"
}

# ttyd Terminal (nixos-desktop)
resource "cloudflare_dns_record" "desktop_ttyd" {
  zone_id = var.cloudflare_zone_id
  name    = "desktop-terminal"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Terminal (Desktop) via desktop-services tunnel"
}

# OpenSearch Dashboards
resource "cloudflare_dns_record" "opensearch_dashboards" {
  zone_id = var.cloudflare_zone_id
  name    = "opensearch"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - OpenSearch Dashboards via desktop-services tunnel"
}

# Google Calendar Bot
resource "cloudflare_dns_record" "calendar_bot" {
  zone_id = var.cloudflare_zone_id
  name    = "calendar-bot"
  content = local.desktop_tunnel_endpoint
  type    = "CNAME"
  ttl     = 1
  proxied = true
  comment = "Managed by Terraform - Google Calendar Bot via desktop-services tunnel"
}

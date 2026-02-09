# Cloudflare Provider設定
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# ローカル変数でドメイン情報を定義
locals {
  # ベースドメイン
  base_domain = "shinbunbun.com"

  # home-services (homeMachine) のドメイン
  home_services = {
    grafana = "grafana.${local.base_domain}"
    cockpit = "cockpit.${local.base_domain}"
    ttyd    = "terminal.${local.base_domain}"
  }

  # desktop-services (nixos-desktop) のドメイン
  desktop_services = {
    cockpit               = "desktop-cockpit.${local.base_domain}"
    ttyd                  = "desktop-terminal.${local.base_domain}"
    opensearch_dashboards = "opensearch.${local.base_domain}"
    calendar_bot          = "calendar-bot.${local.base_domain}"
  }

  # Cloudflare Tunnel エンドポイント
  # トンネルへのCNAMEレコードは <tunnel-id>.cfargotunnel.com を指す
  home_tunnel_endpoint    = "${var.home_tunnel_id}.cfargotunnel.com"
  desktop_tunnel_endpoint = "${var.desktop_tunnel_id}.cfargotunnel.com"
}

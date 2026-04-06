/*
  nixos-desktop用Cloudflare Tunnel設定

  機能:
  - nixos-desktop専用のトンネル設定
  - Cockpit、OpenSearch Dashboards、ArgoCDをCloudflare経由で公開
  - SOPS統合による認証情報管理

  注意:
  - Cloudflare Zero Trust Accessの認証ポリシーは
    別途Cloudflareダッシュボードまたは
    Terraformで設定する必要があります
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;
  tunnelConfig = cfg.cloudflare.desktop;
in
{
  # Cloudflare Tunnel設定
  services.cloudflared = {
    enable = true;
    tunnels = {
      "desktop-services" = {
        default = "http_status:404";
        credentialsFile = config.sops.templates."cloudflare/desktop-tunnel-credentials.json".path;

        ingress = {
          # Cockpit - Zero Trust Accessで認証必要
          "${tunnelConfig.cockpit.domain}" = {
            service = "http://localhost:${toString cfg.management.cockpit.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${tunnelConfig.cockpit.domain}";
              originServerName = "${tunnelConfig.cockpit.domain}";
            };
          };

          # OpenSearch Dashboards - Zero Trust Accessで認証必要
          "${cfg.opensearchDashboards.domain}" = {
            service = "http://localhost:${toString cfg.opensearchDashboards.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${cfg.opensearchDashboards.domain}";
              originServerName = "${cfg.opensearchDashboards.domain}";
            };
          };

          # Google Calendar Bot - Zero Trust Accessで認証必要
          "${tunnelConfig.calendarBot.domain}" = {
            service = "http://${cfg.k3s.cluster.traefikVIP}:80"; # Traefik LB VIP (k8s)
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${tunnelConfig.calendarBot.domain}";
              originServerName = "${tunnelConfig.calendarBot.domain}";
            };
          };

          # mixi2 Bot - Webhook受信用
          "${tunnelConfig.mixi2Bot.domain}" = {
            service = "http://${cfg.k3s.cluster.traefikVIP}:80"; # Traefik LB VIP (k8s)
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${tunnelConfig.mixi2Bot.domain}";
              originServerName = "${tunnelConfig.mixi2Bot.domain}";
            };
          };

          # ArgoCD - Zero Trust Accessで認証必要
          "${tunnelConfig.argocd.domain}" = {
            service = "http://${cfg.k3s.cluster.traefikVIP}:80"; # Traefik LB VIP
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${tunnelConfig.argocd.domain}";
              originServerName = "${tunnelConfig.argocd.domain}";
            };
          };

          # Nextcloud - Zero Trust Accessで認証必要
          "${tunnelConfig.nextcloud.domain}" = {
            service = "http://localhost:${toString cfg.nextcloud.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${tunnelConfig.nextcloud.domain}";
              originServerName = "${tunnelConfig.nextcloud.domain}";
            };
          };

          # Immich - Zero Trust Accessで認証必要（モバイルはService Token）
          "${tunnelConfig.immich.domain}" = {
            service = "http://localhost:${toString cfg.immich.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${tunnelConfig.immich.domain}";
              originServerName = "${tunnelConfig.immich.domain}";
            };
          };
        };
      };
    };
  };

  # SOPS設定
  sops.secrets."cloudflare/desktop-account-tag" = {
    sopsFile = "${inputs.self}/secrets/cloudflare.yaml";
  };
  sops.secrets."cloudflare/desktop-tunnel-id" = {
    sopsFile = "${inputs.self}/secrets/cloudflare.yaml";
  };
  sops.secrets."cloudflare/desktop-tunnel-secret" = {
    sopsFile = "${inputs.self}/secrets/cloudflare.yaml";
  };

  sops.templates."cloudflare/desktop-tunnel-credentials.json" = {
    content = ''
      {
        "AccountTag": "${config.sops.placeholder."cloudflare/desktop-account-tag"}",
        "TunnelID": "${config.sops.placeholder."cloudflare/desktop-tunnel-id"}",
        "TunnelSecret": "${config.sops.placeholder."cloudflare/desktop-tunnel-secret"}"
      }
    '';
  };

  # systemd設定
  systemd.services."cloudflared-tunnel-desktop-services" = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}

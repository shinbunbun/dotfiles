/*
  統合Cloudflare Tunnel設定

  機能:
  - すべてのサービスを1つのトンネルで管理
  - 各サービスへのルーティング設定
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
  domain = cfg.networking.hosts.nixos.domain;
in
{
  # Cloudflare Tunnel統合設定
  services.cloudflared = {
    enable = true;
    tunnels = {
      "home-services" = {
        default = "http_status:404";
        credentialsFile = config.sops.templates."cloudflare/tunnel-credentials.json".path;

        ingress = {
          # Authentik (認証プロバイダー) - Zero Trust Accessで認証不要に設定
          "auth.${domain}" = {
            service = "http://localhost:9000";
            originRequest.noTLSVerify = true;
          };

          # Grafana - Zero Trust Accessで認証必要
          "${cfg.monitoring.grafana.domain}" = {
            service = "http://localhost:${toString cfg.monitoring.grafana.port}";
            originRequest.noTLSVerify = true;
          };

          # Obsidian LiveSync - Zero Trust Accessで認証必要
          "private-obsidian.${domain}" = {
            service = "http://localhost:5984";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "private-obsidian.${domain}";
            };
          };

          # Cockpit - Zero Trust Accessで認証必要
          "cockpit.${domain}" = {
            service = "http://localhost:${toString cfg.management.cockpit.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "cockpit.${domain}";
              originServerName = "cockpit.${domain}";
            };
          };

          # ttyd Terminal - Zero Trust Accessで認証必要
          "terminal.${domain}" = {
            service = "http://localhost:${toString cfg.management.ttyd.port}";
            originRequest = {
              noTLSVerify = true;
              # WebSocket対応
              httpHostHeader = "terminal.${domain}";
              originServerName = "terminal.${domain}";
            };
          };

          # Attic Binary Cache
          "${cfg.attic.domain}" = {
            service = "http://localhost:${toString cfg.attic.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${cfg.attic.domain}";
              originServerName = "${cfg.attic.domain}";
            };
          };

          # SSH for CI/CD deployment (Cloudflare Tunnel経由)
          "${cfg.deploy.sshDomain}" = {
            service = "ssh://localhost:${toString cfg.ssh.port}";
          };
        };
      };
    };
  };

  # SOPS設定
  sops.secrets."cloudflare/account-tag" = {
    sopsFile = "${inputs.self}/secrets/cloudflare.yaml";
  };
  sops.secrets."cloudflare/tunnel-id" = {
    sopsFile = "${inputs.self}/secrets/cloudflare.yaml";
  };
  sops.secrets."cloudflare/tunnel-secret" = {
    sopsFile = "${inputs.self}/secrets/cloudflare.yaml";
  };

  sops.templates."cloudflare/tunnel-credentials.json" = {
    content = ''
      {
        "AccountTag": "${config.sops.placeholder."cloudflare/account-tag"}",
        "TunnelID": "${config.sops.placeholder."cloudflare/tunnel-id"}",
        "TunnelSecret": "${config.sops.placeholder."cloudflare/tunnel-secret"}"
      }
    '';
  };

  # systemd設定
  systemd.services."cloudflared-tunnel-home-services" = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}

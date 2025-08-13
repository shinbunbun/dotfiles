/*
  nixos-desktop用Cloudflare Tunnel設定

  機能:
  - nixos-desktop専用のトンネル設定
  - CockpitとttydをCloudflare経由で公開
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

          # ttyd Terminal - Zero Trust Accessで認証必要
          "${tunnelConfig.ttyd.domain}" = {
            service = "http://localhost:${toString cfg.management.ttyd.port}";
            originRequest = {
              noTLSVerify = true;
              # WebSocket対応
              httpHostHeader = "${tunnelConfig.ttyd.domain}";
              originServerName = "${tunnelConfig.ttyd.domain}";
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

/*
  Cloudflare Tunnel設定（homeMachine ローカルサービス向け）

  機能:
  - homeMachine のローカルサービスへのトンネルアクセス
  - SOPS統合による認証情報管理

  注意:
  - k3s 上のアプリ（grafana, authentik 等）は k3s 内の cloudflared で処理される
  - このモジュールは localhost サービス専用
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
          # Cockpit - Zero Trust Accessで認証必要
          "cockpit.${domain}" = {
            service = "http://localhost:${toString cfg.management.cockpit.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "cockpit.${domain}";
              originServerName = "cockpit.${domain}";
            };
          };

          # Attic Binary Cache
          "${cfg.attic.domain}" = {
            service = "http://localhost:${toString cfg.attic.port}";
            originRequest = {
              noTLSVerify = true;
              httpHostHeader = "${cfg.attic.domain}";
              originServerName = "${cfg.attic.domain}";
              # 大きなファイルのアップロード用にタイムアウトを延長
              connectTimeout = "5m";
              noHappyEyeballs = true;
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

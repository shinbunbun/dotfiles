/*
  Cockpit - ウェブベースのサーバー管理インターフェース

  機能:
  - システムモニタリング（CPU、メモリ、ディスク使用状況）
  - サービス管理
  - ログ閲覧
  - ネットワーク設定
  - ターミナルアクセス

  設定:
  - ポート9091でリッスン
  - HTTPS有効化（証明書はnginx/Caddyから取得）
  - PAM認証（将来的にAuthentik OIDC統合予定）
*/
{ config, pkgs, lib, ... }:
let
  cfg = import ../../../../shared/config.nix;
  enable = cfg.management.cockpit.enable;
  port = cfg.management.cockpit.port;
  domain = cfg.management.cockpit.domain;
  allowedNetworks = cfg.networking.allowedNetworks;
in
{
  config = lib.mkIf enable {
    # Cockpitサービスを有効化
    services.cockpit = {
      enable = true;
      port = port;
      openFirewall = false; # ファイアウォールは手動で制御

      settings = {
        WebService = {
          # Origins設定でCORSを制御
          Origins = lib.mkForce "https://${domain} wss://${domain}";
          # プロトコルヘッダーを信頼（リバースプロキシ使用時）
          ProtocolHeader = "X-Forwarded-Proto";
          # ログインページのブランディング
          LoginTitle = "Server Management Portal";
          # HTTPS無効化（Cloudflare Tunnel経由なので不要）
          AllowUnencrypted = true;
        };

        # セッション設定
        Session = {
          # セッションタイムアウト（分）
          IdleTimeout = 15;
          # バナーメッセージ
          Banner = "/etc/cockpit/issue.cockpit";
        };
      };
    };

    # Cockpitバナーファイル
    environment.etc."cockpit/issue.cockpit".text = ''
      Welcome to ${config.networking.hostName} Management Portal

      This system is for authorized use only.
      All activities are monitored and logged.
    '';

    # ファイアウォール設定 - 特定のネットワークからのみ許可
    networking.firewall.extraCommands = lib.mkIf config.networking.firewall.enable ''
      # Cockpitアクセスを制限
      ${lib.concatMapStrings (network: ''
        iptables -A nixos-fw -p tcp --dport ${toString port} -s ${network} -j ACCEPT
      '') allowedNetworks}

      # WireGuardインターフェースからのアクセスを許可
      iptables -A nixos-fw -p tcp --dport ${toString port} -i wg0 -j ACCEPT
    '';

    # システムパッケージ
    environment.systemPackages = with pkgs; [
      # Cockpit追加モジュール（利用可能な場合）
      # cockpit-podman
      # cockpit-machines
    ];

    # PAM設定の準備（将来的なOIDC統合用）
    # security.pam.services.cockpit = {
    #   # PAM OIDC設定をここに追加
    # };
  };
}


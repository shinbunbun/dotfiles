/*
  peer-issuer サービスモジュール

  WireGuard peer を動的に発行・解放する HTTP API サービスを提供します：
  - RouterOS に SSH 経由で WireGuard peer を追加・削除
  - SQLite で lease 管理、IP プール割り当て
  - TTL ベースの自動掃除
  - SOPS によるシークレット管理（SSH鍵、WG公開鍵）

  使用方法:
  - services.peerIssuer.enable = true; で有効化
  - secrets/peer-issuer.yaml に認証情報を SOPS 暗号化で格納
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

with lib;

let
  cfg = config.services.peerIssuer;
  configValues = import ../../../../shared/config.nix;
in
{
  options.services.peerIssuer = {
    enable = mkEnableOption "peer-issuer WireGuard peer provisioning API";
  };

  config = mkIf cfg.enable {
    # SOPS シークレット設定
    sops.secrets = {
      "peer_issuer_router_ssh_key" = {
        sopsFile = "${inputs.self}/secrets/peer-issuer.yaml";
        owner = "peer-issuer";
        group = "peer-issuer";
        mode = "0400";
      };
      "peer_issuer_router_host_key" = {
        sopsFile = "${inputs.self}/secrets/peer-issuer.yaml";
        owner = "peer-issuer";
        group = "peer-issuer";
        mode = "0400";
      };
      "peer_issuer_wg_server_pubkey" = {
        sopsFile = "${inputs.self}/secrets/peer-issuer.yaml";
        owner = "peer-issuer";
        group = "peer-issuer";
        mode = "0400";
      };
      "peer_issuer_wg_endpoint" = {
        sopsFile = "${inputs.self}/secrets/peer-issuer.yaml";
        owner = "peer-issuer";
        group = "peer-issuer";
        mode = "0400";
      };
    };

    # SOPS テンプレートで環境変数ファイルを生成
    sops.templates."peer-issuer/env" = {
      content = ''
        LISTEN_ADDR=${configValues.peerIssuer.listenAddr}
        DB_PATH=${configValues.peerIssuer.dbPath}
        CI_POOL_CIDR=${configValues.peerIssuer.poolCIDR}
        ROUTER_HOST=${configValues.peerIssuer.routerHost}
        ROUTER_SSH_PORT=${toString configValues.peerIssuer.routerPort}
        ROUTER_USER=${configValues.peerIssuer.routerUser}
        ROUTER_SSH_KEY=${config.sops.secrets."peer_issuer_router_ssh_key".path}
        ROUTER_HOST_KEY=${config.sops.placeholder."peer_issuer_router_host_key"}
        ROUTER_WG_IF=${configValues.peerIssuer.routerWgInterface}
        WG_SERVER_PUBKEY=${config.sops.placeholder."peer_issuer_wg_server_pubkey"}
        WG_ENDPOINT=${config.sops.placeholder."peer_issuer_wg_endpoint"}
        WG_MTU=${toString configValues.peerIssuer.wgMTU}
        WG_KEEPALIVE=${toString configValues.peerIssuer.wgKeepalive}
        DEFAULT_TTL=${toString configValues.peerIssuer.defaultTTL}
      '';
      path = "/run/secrets/rendered/peer-issuer/env";
      owner = "peer-issuer";
      group = "peer-issuer";
      mode = "0400";
    };

    # 専用システムユーザー
    users.users.peer-issuer = {
      isSystemUser = true;
      group = "peer-issuer";
      home = configValues.peerIssuer.stateDirectory;
      description = "peer-issuer service user";
    };
    users.groups.peer-issuer = { };

    # systemd サービス
    systemd.services.peer-issuer = {
      description = "WireGuard Peer Issuer API";
      after = [
        "network-online.target"
        "sops-nix.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${inputs.peer-issuer.packages.x86_64-linux.default}/bin/peer-issuer";
        EnvironmentFile = config.sops.templates."peer-issuer/env".path;
        User = "peer-issuer";
        Group = "peer-issuer";
        StateDirectory = "peer-issuer";

        # セキュリティ強化
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        ReadWritePaths = [ configValues.peerIssuer.stateDirectory ];

        # リスタートポリシー
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # データディレクトリの作成
    systemd.tmpfiles.rules = [
      "d ${configValues.peerIssuer.stateDirectory} 0750 peer-issuer peer-issuer -"
    ];

    # ファイアウォール設定
    networking.firewall.allowedTCPPorts = [ configValues.peerIssuer.listenPort ];
  };
}

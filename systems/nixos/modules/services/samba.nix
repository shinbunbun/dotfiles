/*
  Samba - SMBファイル共有サーバー

  機能:
  - SMB3以上のプロトコルのみ対応（セキュリティ確保）
  - macOS互換VFS（fruit, streams_xattr）
  - ゲストアクセス禁止
  - journaldログ出力（既存FluentBit経由でLoki/Grafanaに自動収集）
  - WS-Discovery対応（macOS/Windowsからの自動検出）

  設定:
  - TCP 445 でリッスン（allowedNetworksからのみ許可）
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;
  enable = cfg.samba.enable;
  workgroup = cfg.samba.workgroup;
  serverString = cfg.samba.serverString;
  allowedNetworks = cfg.networking.allowedNetworks;

  # allowedNetworksをSamba hosts allow形式に変換
  hostsAllow = lib.concatStringsSep " " allowedNetworks;
in
{
  config = lib.mkIf enable {
    services.samba = {
      enable = true;
      openFirewall = false; # ファイアウォールは手動で制御

      settings = {
        global = {
          workgroup = workgroup;
          "server string" = serverString;

          # セキュリティ設定
          "server min protocol" = "SMB3_00";
          "map to guest" = "never";

          # macOS互換性
          "vfs objects" = "fruit streams_xattr";
          "fruit:metadata" = "stream";
          "fruit:model" = "MacSamba";
          "fruit:posix_rename" = "yes";
          "fruit:veto_appledouble" = "no";
          "fruit:nfs_aces" = "no";
          "fruit:wipe_intentionally_left_blank_rfork" = "yes";
          "fruit:delete_empty_adfiles" = "yes";

          # ログ設定
          logging = "systemd";

          # アクセス制御
          "hosts allow" = hostsAllow;
          "hosts deny" = "0.0.0.0/0";

          # パフォーマンス
          "use sendfile" = "yes";
        };
      };
    };

    # WS-Discovery（macOS/Windowsからの自動検出）
    services.samba-wsdd = {
      enable = true;
      openFirewall = true; # discovery用ポートはLAN内で開放
    };

    # ファイアウォール設定 - 特定のネットワークからのみ許可
    networking.firewall.extraCommands = lib.mkIf config.networking.firewall.enable ''
      # Sambaアクセスを制限（TCP 445）
      ${lib.concatMapStrings (network: ''
        iptables -A nixos-fw -p tcp --dport 445 -s ${network} -j ACCEPT
      '') allowedNetworks}

      # WireGuardインターフェースからのアクセスを許可
      iptables -A nixos-fw -p tcp --dport 445 -i wg0 -j ACCEPT
    '';
  };
}

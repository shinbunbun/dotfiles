/*
  Samba - SMBファイル共有サーバー

  機能:
  - SMB3以上のプロトコルのみ対応（セキュリティ確保）
  - macOS接続安定性（keepalive、マルチチャネル制御）
  - macOS互換VFS（fruit, streams_xattr）
  - ゲストアクセス禁止
  - journaldログ出力（既存FluentBit経由でLoki/Grafanaに自動収集）
  - WS-Discovery対応（macOS/Windowsからの自動検出）

  設定:
  - TCP 445 でリッスン（hosts allow/denyでアクセス制御）
*/
{ lib, ... }:
let
  cfg = import ../../../../shared/config.nix;
  enable = cfg.samba.enable;
  workgroup = cfg.samba.workgroup;
  serverString = cfg.samba.serverString;
  keepalive = cfg.samba.keepalive;
  deadTime = cfg.samba.deadTime;
  serverMultiChannelSupport = cfg.samba.serverMultiChannelSupport;
  allowedNetworks = cfg.networking.allowedNetworks;

  # allowedNetworksをSamba hosts allow形式に変換
  hostsAllow = lib.concatStringsSep " " allowedNetworks;
in
{
  config = lib.mkIf enable {
    services.samba = {
      enable = true;
      openFirewall = true;

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

          # macOS接続安定性
          "keepalive" = keepalive;
          "dead time" = deadTime;
          "server multi channel support" = if serverMultiChannelSupport then "yes" else "no";

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

  };
}

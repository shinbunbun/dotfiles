/*
  Nextcloud - ファイル管理・共有プラットフォーム

  機能:
  - ファイルの同期・共有（WebDAV対応）
  - nginxによるWebサーバー自動設定
  - カスタムポートでのリッスン（デフォルト80を回避）

  設定:
  - shared/config.nix の nextcloud セクションで有効化
  - hostName は nextcloud.domain から取得
  - nginx のリッスンポートは nextcloud.port でカスタマイズ
  - adminpassFile 等のシークレットはホスト固有設定で注入
*/
{ lib, pkgs, ... }:
let
  cfg = import ../../../../shared/config.nix;
  enable = cfg.nextcloud.enable;
  port = cfg.nextcloud.port;
  domain = cfg.nextcloud.domain;
in
{
  config = lib.mkIf enable {
    services.nextcloud = {
      enable = true;
      package = pkgs.nextcloud32;
      hostName = domain;

      # SQLite（小規模利用、将来PostgreSQLに移行可能）
      config.dbtype = "sqlite";

      # ログはjournald出力（既存FluentBit経由でLoki/Grafanaに自動収集）
      settings.log_type = "systemd";

      # 日本語環境
      settings.default_phone_region = "JP";

      # 最大アップロードサイズ
      maxUploadSize = "10G";
    };

    # nginxのリッスンポートをカスタマイズ
    # NixOSのnextcloudモジュールが自動生成するvirtualHostのデフォルトポート(80)を上書き
    services.nginx.virtualHosts.${domain}.listen = [
      {
        addr = "0.0.0.0";
        port = port;
      }
    ];

    # ファイアウォール: カスタムポートを許可
    networking.firewall.allowedTCPPorts = [ port ];
  };
}

/*
  共通ネットワーク設定モジュール

  このモジュールは全NixOSホストで共通のネットワーク設定を提供します：
  - IPv6サポート
  - ファイアウォール設定（汎用ポート）
  - Avahi mDNSサービス

  ホスト固有の設定（hostname, domain, インターフェース, extraHosts）は
  各ホストの default.nix で設定してください。

  config.nixの値を参照して設定を行います。
*/
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = import ../../../shared/config.nix;
in
{
  networking.enableIPv6 = true;

  networking.firewall.allowedTCPPorts = [
    cfg.networking.firewall.generalPort # General purpose
  ];

  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}

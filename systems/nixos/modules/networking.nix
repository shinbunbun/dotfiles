/*
  ネットワーク設定モジュール

  このモジュールは以下のネットワーク関連設定を提供します：
  - ホスト名とドメイン名の設定
  - ネットワークインターフェースの設定（有線・無線）
  - IPv6サポート
  - ファイアウォール設定（TCP/UDPポート）
  - systemd-resolvedによる名前解決
  - 時刻同期（NTP）設定

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
  networking.hostName = cfg.networking.hosts.nixos.hostname;
  networking.domain = cfg.networking.hosts.nixos.domain;
  networking.useDHCP = false;
  networking.interfaces.${cfg.networking.interfaces.primary}.useDHCP = true;
  networking.interfaces.${cfg.networking.interfaces.wireless}.useDHCP = false;
  networking.enableIPv6 = true;

  networking.firewall.allowedTCPPorts = [
    cfg.networking.firewall.generalPort # General purpose
  ];

  networking.extraHosts = ''
    ${cfg.networking.hosts.nixosDesktop.ip} ${cfg.networking.hosts.nixosDesktop.hostname}
  '';

  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}

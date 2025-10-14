/*
  NixOS設定 - nixos-desktop

  このファイルはnixos-desktopのシステム設定を定義します。
  デスクトップ用途のため、サーバー関連のサービスは含まれていません。
  基本的なシステム設定、デスクトップ環境、ユーザー環境を提供します。
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
  desktopUsername = cfg.users.nixos.username;
in
{
  imports = [
    # ハードウェア設定
    ./hardware.nix

    # 基本モジュール
    ../../modules/base.nix
    ../../modules/optimise.nix
    ../../modules/security.nix
    ../../modules/system-tools.nix
    ../../modules/desktop.nix

    # 管理インターフェース
    ../../modules/services/cockpit.nix
    ../../modules/services/ttyd.nix
    ../../modules/services/desktop-cloudflare-tunnel.nix

    # ログ検索基盤（OpenSearch）
    ../../modules/services/opensearch.nix
    ../../modules/services/opensearch-dashboards.nix # Docker版
    ../../modules/services/fluent-bit.nix

    # 外部モジュール
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  # システム設定
  networking.hostName = cfg.networking.hosts.nixosDesktop.hostname;
  system.stateVersion = cfg.system.nixosStateVersion;

  # Lokiサーバーへの名前解決設定
  networking.extraHosts = ''
    192.168.1.3 nixos.shinbunbun.com nixos
  '';

  # ネットワーク設定（デスクトップ用）
  networking.useDHCP = false;
  networking.enableIPv6 = true;

  # SSH設定
  services.openssh = {
    enable = true;
    ports = [ cfg.ssh.port ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      X11Forwarding = true;
    };
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [
    cfg.ssh.port # SSH
  ];

  # Nixpkgs設定
  nixpkgs.config.allowUnfree = true;

  # Fail2ban設定（デスクトップ用にカスタマイズ）
  services.fail2ban = {
    enable = true;
    ignoreIP = cfg.fail2ban.ignoreNetworks;
  };

  # Node Exporterのみ有効化（homeMachineのPrometheusが収集）
  services.prometheus.exporters.node = {
    enable = true;
    port = cfg.monitoring.nodeExporter.port;
    openFirewall = true; # homeMachineからアクセス可能にする
    enabledCollectors = [
      "cpu"
      "diskstats"
      "filesystem"
      "loadavg"
      "meminfo"
      "netdev"
      "stat"
      "time"
      "vmstat"
      "systemd"
      "processes"
    ];
    extraFlags = [
      "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/user/.+)($|/)"
      "--collector.netdev.device-exclude=^(veth.*|br.*|docker.*|virbr.*|lo|wlp[12]s0)$"
    ];
  };

  # Home Manager設定
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${desktopUsername} = import ../../../../home/profiles/bunbun { inherit inputs pkgs; };
  };
}

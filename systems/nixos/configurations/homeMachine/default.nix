/*
  NixOS設定 - homeMachine

  このファイルはhomeMachineのシステム設定を定義します。
  必要なモジュールをインポートし、システム固有の設定を行います。
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
  homeMachineUsername = cfg.users.nixos.username;
  isVM = builtins.getEnv "NIXOS_BUILD_VM" == "1";
in
{
  imports = [
    # ハードウェア設定
    (if isVM then ../../modules/vm.nix else ./hardware.nix)

    # ホスト固有の設定
    ./observability.nix

    # 基本モジュール
    ../../modules/base.nix
    ../../modules/optimise.nix
    ../../modules/networking.nix
    ../../modules/security.nix
    ../../modules/system-tools.nix
    ../../modules/wireguard.nix
    ../../modules/nfs.nix
    ../../modules/kubernetes.nix

    # サービスモジュール
    ../../modules/services/services.nix
    # ../../modules/services/monitoring.nix          # nixos-observability に移行
    ../../modules/services/alertmanager.nix
    ../../modules/services/loki.nix
    ../../modules/services/fluent-bit.nix
    ../../modules/services/authentik.nix
    ../../modules/services/cockpit.nix
    ../../modules/services/ttyd.nix
    ../../modules/services/obsidian-livesync.nix
    ../../modules/services/routeros-backup.nix
    ../../modules/services/unified-cloudflare-tunnel.nix

    # 外部モジュール
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.vscode-server.nixosModules.default
    inputs.nixos-observability.nixosModules.monitoring
  ];

  # システム設定
  networking.hostName = cfg.networking.hosts.nixos.hostname;
  system.stateVersion = cfg.system.nixosStateVersion;

  # Nixpkgs設定
  nixpkgs.config.allowUnfree = true;

  # RouterOSバックアップ設定
  services.routerosBackup = {
    enable = true;
    gitRepo = "git@github.com:shinbunbun/routeros-backups.git";
  };

  # VS Code Server設定
  services.vscode-server.enable = true;

  # Home Manager設定
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${homeMachineUsername} = import ../../../../home/profiles/bunbun { inherit inputs pkgs; };
  };
}

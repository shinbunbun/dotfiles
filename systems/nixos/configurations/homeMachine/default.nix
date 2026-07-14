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
in
{
  imports = [
    # ハードウェア設定
    ./hardware.nix

    # ホスト固有の設定
    ./observability.nix
    ./github-runner.nix
    ./disk-monitoring.nix

    # disk-monitoring 共通モジュール (services.disk-monitoring を提供)
    ../../modules/services/disk-monitoring.nix

    # 基本モジュール
    ../../modules/base.nix
    # nix-ld: uvx 由来の standalone Python (mcp-server-motherduck = DuckDB ネイティブ
    # 拡張) が libstdc++.so.6 を解決できるようにする
    ../../modules/nix-ld.nix
    ../../modules/optimise.nix
    ../../modules/networking.nix
    ../../modules/security.nix
    ../../modules/system-tools.nix
    ../../modules/wireguard.nix

    # サービスモジュール
    ../../modules/services/mosh.nix
    ../../modules/services/services.nix
    ../../modules/services/cockpit.nix
    ../../modules/services/attic.nix
    ../../modules/services/deploy-user.nix
    ../../modules/services/unified-cloudflare-tunnel.nix

    # Kubernetes
    ../../modules/k3s.nix

    # 外部モジュール
    inputs.attic.nixosModules.atticd
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    # vscode-server は flake=false で取り込み、モジュールを直接 import する（flake.nix 参照）
    (import "${inputs.vscode-server}/modules/vscode-server")
    inputs.nixos-observability.nixosModules.monitoring
    # nixos-observability.nixosModules.loki は k3s に移行したため削除
    inputs.nixos-observability.nixosModules.fluentBit
  ];

  # システム設定
  networking.hostName = cfg.networking.hosts.nixos.hostname;
  networking.domain = cfg.networking.hosts.nixos.domain;
  system.stateVersion = cfg.system.nixosStateVersion;

  # ネットワーク設定（homeMachine固有）
  networking.useDHCP = false;
  networking.interfaces.${cfg.networking.interfaces.homeMachine.primary}.useDHCP = true;
  networking.interfaces.${cfg.networking.interfaces.homeMachine.wireless}.useDHCP = false;
  networking.extraHosts = ''
    ${cfg.networking.hosts.nixosDesktop.ip} ${cfg.networking.hosts.nixosDesktop.hostname}
  '';

  # Nixpkgs設定
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];
  nixpkgs.overlays = [
    inputs.claude-code.overlays.default
  ];

  # VS Code Server設定
  services.vscode-server.enable = true;

  # Home Manager設定
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${homeMachineUsername} = import ../../../../home/profiles/bunbun { inherit inputs pkgs; };
  };
}

/*
  NixOS設定 - g3pro (GMKTec G3 Pro)

  このファイルはg3proのシステム設定を定義します。
  サーバー・開発・ホームラボ用途のミニPC（Intel N150）です。

  インポートするモジュール:
  - base: Nix設定、ユーザー、基本パッケージ
  - optimise: ガベージコレクション
  - networking: IPv6、Avahi、ファイアウォール（汎用）
  - security: PAM、Polkit、SOPS
  - system-tools: ユーティリティ
  - services: SSH + Docker + Fail2ban
  - mosh: Mobile Shell
  - deploy-user: deploy-rs用ユーザー
  - observability: Node Exporter + Fluent Bit
  - home-manager: bunbunプロファイル（claude, shell, git, tmux, editors）
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
  g3proUsername = cfg.users.nixos.username;
in
{
  imports = [
    # ハードウェア設定
    ./hardware.nix

    # ホスト固有の設定
    ./observability.nix

    # 基本モジュール
    ../../modules/base.nix
    ../../modules/optimise.nix
    ../../modules/networking.nix
    ../../modules/security.nix
    ../../modules/system-tools.nix

    # サービスモジュール
    ../../modules/services/services.nix
    ../../modules/services/mosh.nix
    ../../modules/services/deploy-user.nix

    # Kubernetes
    ../../modules/k3s.nix

    # 外部モジュール
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.vscode-server.nixosModules.default
    inputs.nixos-observability.nixosModules.fluentBit
  ];

  # システム設定
  networking.hostName = cfg.networking.hosts.g3pro.hostname;
  # TODO: 実機で nixos-generate-config が生成する値に差し替える
  system.stateVersion = "25.11";

  # ネットワーク設定（g3pro固有）
  # グローバルDHCPを無効化し、物理インター��ェースのみDHCPを有効化
  # （Cilium仮想インターフェースへのDHCPパケット送信を防止）
  networking.useDHCP = false;
  networking.interfaces.${cfg.networking.interfaces.g3pro.primary}.useDHCP = true;
  networking.extraHosts = ''
    ${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain} ${cfg.networking.hosts.nixos.hostname}
    ${cfg.networking.hosts.nixosDesktop.ip} ${cfg.networking.hosts.nixosDesktop.hostname}
    ${cfg.networking.hosts.macmini.ip} ${cfg.networking.hosts.macmini.hostname}
  '';

  # Nixpkgs設定
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    inputs.claude-code.overlays.default
  ];

  # VS Code Server設定
  services.vscode-server.enable = true;

  # Home Manager設定
  # bunbunプロファイル経由で以下が適用される:
  # - claude (ai-tools.nix), shell (shell-tools.nix), git (version-control.nix)
  # - tmux, editors, security-tools
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${g3proUsername} = import ../../../../home/profiles/bunbun { inherit inputs pkgs; };
  };
}

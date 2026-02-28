/*
  bunbun (NixOS) ユーザープロファイル

  NixOSシステム用のhome-manager設定です。
  開発ツール、シェルツール、セキュリティツールなどを含みます。
*/
{ inputs, pkgs, ... }:

let
  cfg = import ../../../shared/config.nix;
in
{
  imports = [
    # 開発ツール
    ../../modules/development/ai-tools.nix
    ../../modules/development/cloud-tools.nix
    ../../modules/development/development-tools.nix
    ../../modules/development/editors.nix

    # シェルツール
    ../../modules/shell/shell-tools.nix
    ../../modules/shell/version-control.nix
    ../../modules/shell/tmux.nix

    # セキュリティツール
    ../../modules/security/security-tools.nix
  ];

  # 基本設定
  home.username = cfg.users.nixos.username;
  home.homeDirectory = cfg.users.nixos.homeDirectory;
  home.stateVersion = cfg.system.homeStateVersion;
  xdg.enable = true;

  # ユーザー固有のパッケージ
  home.packages = with pkgs; [
    # システムツール
    gh
    llvm

    # Nix開発ツール
    nil
    nixd
    nixfmt
  ];

  # Home Managerの有効化
  programs.home-manager.enable = true;
}

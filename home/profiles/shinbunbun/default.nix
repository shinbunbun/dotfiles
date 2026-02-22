/*
  shinbunbun (Darwin/macOS) ユーザープロファイル

  macOSシステム用のhome-manager設定です。
  開発ツール、シェルツール、GUI アプリケーションなどを含みます。
*/
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

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

    # セキュリティツール
    ../../modules/security/security-tools.nix
  ];

  # 基本設定
  home.username = lib.mkForce cfg.users.darwin.username;
  home.homeDirectory = lib.mkForce cfg.users.darwin.homeDirectory;
  home.stateVersion = lib.mkForce cfg.system.homeStateVersion;
  xdg.enable = true;

  # ユーザー固有のパッケージ
  home.packages = with pkgs; [
    # システムツール
    gh
    llvm

    # Nix開発ツール
    nil
    nixd
    nixfmt-rfc-style

    # macOS専用アプリケーション
    nerd-fonts.fira-code
  ];

  # Home Managerの有効化
  programs.home-manager.enable = true;

  # フォント設定
  fonts.fontconfig.enable = true;
}

/*
  shinbunbun (Darwin/macOS) ユーザープロファイル

  macOSシステム用のhome-manager設定です。
  共通設定は ../common.nix で管理し、このファイルは
  Darwin ユーザー固有の username/homeDirectory およびフォント設定を宣言します。
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
    ../common.nix
  ];

  # Darwinユーザー固有の設定
  home.username = lib.mkForce cfg.users.darwin.username;
  home.homeDirectory = lib.mkForce cfg.users.darwin.homeDirectory;
  home.stateVersion = lib.mkForce cfg.system.homeStateVersion;

  # macOS専用パッケージ
  home.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  # フォント設定
  fonts.fontconfig.enable = true;
}

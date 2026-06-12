/*
  bunbun (NixOS) ユーザープロファイル

  NixOSシステム用のhome-manager設定です。
  共通設定は ../common.nix で管理し、このファイルは
  NixOSユーザー固有の username/homeDirectory のみ宣言します。
*/
{ inputs, pkgs, ... }:

let
  cfg = import ../../../shared/config.nix;
in
{
  imports = [
    ../common.nix
  ];

  # NixOSユーザー固有の設定
  home.username = cfg.users.nixos.username;
  home.homeDirectory = cfg.users.nixos.homeDirectory;
}

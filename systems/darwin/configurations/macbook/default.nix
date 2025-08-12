/*
  Darwin設定 - macbook

  macOSシステムの設定を定義します。
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
  username = cfg.users.darwin.username;
in
{
  imports = [
    # 基本モジュール
    ../../modules/base.nix
    ../../modules/optimise.nix
    ../../modules/wireguard.nix

    # 外部モジュール
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops
  ];

  # Home Manager設定
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${username} = import ../../../../home/profiles/shinbunbun { inherit inputs pkgs; };
  };
}


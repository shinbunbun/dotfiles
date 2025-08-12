/*
  Darwin最適化設定

  macOS用のNixストア最適化設定を提供します：
  - 自動最適化
  - 週次ガベージコレクション
*/
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # https://wiki.nixos.org/wiki/Storage_optimization
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 0;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };
}

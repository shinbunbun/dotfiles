/*
  Nix最適化設定

  ストアの自動最適化とガベージコレクションを設定し、
  ディスク使用量を抑制します。
*/
{
  config,
  lib,
  pkgs,
  ...
}:

{
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}

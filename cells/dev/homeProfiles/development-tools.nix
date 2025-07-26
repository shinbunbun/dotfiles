# cells/dev/homeProfiles/development-tools.nix
/*
  開発ツール設定モジュール

  このモジュールは開発に必要なツールを提供します：
  - cocoapods: iOS/macOSアプリ開発用のパッケージマネージャー

  モバイルアプリ開発やその他の開発用ツールが含まれます。
*/
{ inputs, cell }:
{ pkgs, ... }:
{
  home.packages = [
    pkgs.cocoapods
  ];
}

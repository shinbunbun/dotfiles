/*
  開発ツール設定モジュール

  このモジュールは開発に必要なツールを提供します：
  - cocoapods: iOS/macOSアプリ開発用のパッケージマネージャー

  モバイルアプリ開発やその他の開発用ツールが含まれます。
*/
{ pkgs, ... }:
{
  home.packages = 
    pkgs.lib.optionals pkgs.stdenv.isDarwin [
      pkgs.cocoapods
    ];
}


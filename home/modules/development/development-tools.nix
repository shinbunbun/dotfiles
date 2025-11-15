/*
  開発ツール設定モジュール

  このモジュールは開発に必要なツールを提供します：
  - cocoapods: iOS/macOSアプリ開発用のパッケージマネージャー
  - terraform: インフラストラクチャを code として管理するツール

  モバイルアプリ開発やインフラ管理のツールが含まれます。
*/
{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      terraform
      pnpm
    ]
    ++ lib.optionals stdenv.isDarwin [
      cocoapods
    ];
}

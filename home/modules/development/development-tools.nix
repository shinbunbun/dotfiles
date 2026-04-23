/*
  開発ツール設定モジュール

  このモジュールは開発に必要なツールを提供します：
  - cocoapods: iOS/macOSアプリ開発用のパッケージマネージャー
  - terraform: インフラストラクチャを code として管理するツール
  - pnpm: Node.js パッケージマネージャー
  - kubectl-cnpg: CloudNativePG (k3s 上の PostgreSQL Cluster) 管理用 kubectl プラグイン
    (`kubectl cnpg restart`, `kubectl cnpg status`, `kubectl cnpg backup` 等)

  モバイルアプリ開発やインフラ管理のツールが含まれます。
*/
{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      terraform
      pnpm
      kubectl-cnpg
    ]
    ++ lib.optionals stdenv.isDarwin [
      cocoapods
    ];
}

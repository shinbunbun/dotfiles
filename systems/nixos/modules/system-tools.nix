/*
  システムツール設定モジュール

  このモジュールはシステム管理用のツールを提供します：
  - polkit: 権限管理ツール
  - wireguard-tools: WireGuard VPN管理ツール
  - jq: JSONデータ処理ツール
  - openssl: 暗号化ツール
  - python3: スクリプト実行環境
  - gnumake: ビルド自動化ツール

  これらのツールをシステム全体で利用可能にします。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = [
    pkgs.polkit
    pkgs.wireguard-tools
    pkgs.jq
    pkgs.openssl
    pkgs.python3
    pkgs.gnumake
  ];
}

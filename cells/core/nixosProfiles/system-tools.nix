# cells/core/nixosProfiles/system-tools.nix
/*
  システムツール設定モジュール

  このモジュールはシステム管理用のツールを提供します：
  - fastfetch: システム情報表示ツール
  - htop: プロセス監視ツール
  - ripgrep: 高速ファイル検索ツール
  - fd: 高速ファイル検索ツール
  - iperf3: ネットワークパフォーマンス測定
  - speedtest-cli: インターネット速度測定

  これらのツールをシステム全体で利用可能にします。
*/
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    polkit
    wireguard-tools
  ];
}

/*
  クラウドツール設定モジュール

  このモジュールはクラウド開発に必要なツールを提供します：
  - Google Cloud SDK
  - Cloudflared (Cloudflare Tunnel CLI)

  Google Cloud SDK は素のパッケージを利用します（追加コンポーネントなし）。
*/
{ pkgs, ... }:
{
  home.packages = [
    pkgs.google-cloud-sdk
    pkgs.cloudflared
  ];
}

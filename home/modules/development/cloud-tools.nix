/*
  クラウドツール設定モジュール

  このモジュールはクラウド開発に必要なツールを提供します：
  - Google Cloud SDK
  - Cloud Datastore Emulator
  - Cloudflared (Cloudflare Tunnel CLI)

  Google Cloud SDKには必要なコンポーネントが自動的に含まれます。
*/
{ pkgs, ... }:
let
  googleCloudSdkWithCloudDatastoreEmulator = pkgs.google-cloud-sdk.withExtraComponents ([
    pkgs.google-cloud-sdk.components.cloud-datastore-emulator
  ]);
in
{
  home.packages = [
    googleCloudSdkWithCloudDatastoreEmulator
    pkgs.cloudflared
  ];
}


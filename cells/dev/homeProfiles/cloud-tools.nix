# cells/dev/homeProfiles/cloud-tools.nix
/*
  クラウドツール設定モジュール

  このモジュールはクラウド開発に必要なツールを提供します：
  - Google Cloud SDK
  - Cloud Datastore Emulator

  Google Cloud SDKには必要なコンポーネントが自動的に含まれます。
*/
{ inputs, cell }:
{ pkgs, ... }:
let
  googleCloudSdkWithCloudDatastoreEmulator = pkgs.google-cloud-sdk.withExtraComponents ([
    pkgs.google-cloud-sdk.components.cloud-datastore-emulator
  ]);
in
{
  home.packages = [
    googleCloudSdkWithCloudDatastoreEmulator
  ];
}

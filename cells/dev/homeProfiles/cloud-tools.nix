# cells/dev/homeProfiles/cloud-tools.nix
{ inputs, cell }:
{ pkgs, ... }:
let
  googleCloudSdkWithCloudDatastoreEmulator = pkgs.google-cloud-sdk.withExtraComponents ([
    pkgs.google-cloud-sdk.components.cloud-datastore-emulator
  ]);
in
{
  home.packages = with pkgs; [
    googleCloudSdkWithCloudDatastoreEmulator
  ];
}

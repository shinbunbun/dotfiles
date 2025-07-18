# cells/dev/homeProfiles/cloud-tools.nix
{ inputs, cell }:
{ pkgs, ... }:
let
  google-cloud-sdk-with-cloud-datastore-emulator = pkgs.google-cloud-sdk.withExtraComponents ([
    pkgs.google-cloud-sdk.components.cloud-datastore-emulator
  ]);
in
{
  home.packages = with pkgs; [
    google-cloud-sdk-with-cloud-datastore-emulator
  ];
}

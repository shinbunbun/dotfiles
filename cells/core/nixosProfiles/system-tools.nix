# cells/core/nixosProfiles/system-tools.nix
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

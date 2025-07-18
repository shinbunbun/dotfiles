# cells/dev/homeProfiles/development-tools.nix
{ inputs, cell }:
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    cocoapods
  ];
}

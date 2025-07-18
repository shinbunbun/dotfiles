# cells/dev/homeProfiles/security-tools.nix
{ inputs, cell }:
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    age
    sops
  ];
}

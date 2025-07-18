# cells/core/nixosProfiles/kubernetes.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    kompose
    kubectl
    kubernetes
  ];
}

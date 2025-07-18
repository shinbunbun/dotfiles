# cells/core/nixosProfiles/kubernetes.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  kubeMasterIP = "192.168.1.3";
  kubeMasterHostname = "api.kube";
in
{
  # Kubernetes tools
  environment.systemPackages = with pkgs; [
    kompose
    kubectl
    kubernetes
  ];

  # Kubernetes API port
  networking.firewall.allowedTCPPorts = [
    6443 # Kubernetes API
  ];

  # Kubernetes hosts configuration
  networking.extraHosts = ''
    ${kubeMasterIP} ${kubeMasterHostname}
  '';
}

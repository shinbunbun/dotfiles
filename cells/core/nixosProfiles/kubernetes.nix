# cells/core/nixosProfiles/kubernetes.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = import ../config.nix;
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
    cfg.networking.firewall.kubernetesApiPort # Kubernetes API
  ];

  # Kubernetes hosts configuration
  networking.extraHosts = ''
    ${cfg.kubernetes.master.ip} ${cfg.kubernetes.master.hostname}
  '';
}

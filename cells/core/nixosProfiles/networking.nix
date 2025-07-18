# cells/core/nixosProfiles/networking.nix
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
  networking.hostName = "nixos";
  networking.domain = "shinbunbun.com";
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.wlp1s0.useDHCP = false;
  networking.enableIPv6 = true;

  networking.firewall.allowedTCPPorts = [
    6443 # Kubernetes API
    8888 # General purpose
    2049 # NFS
  ];

  networking.extraHosts = ''
    ${kubeMasterIP} ${kubeMasterHostname}
    192.168.1.4 nixos-desktop
  '';

  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}

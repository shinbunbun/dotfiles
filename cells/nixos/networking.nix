{ config, pkgs, ... }:

let
  kubeMasterIP = "192.168.1.3";
  kubeMasterHostname = "api.kube";
in

{
  networking.hostName = "nixos";
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.wlp1s0.useDHCP = false;
  networking.enableIPv6 = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 6443 8888 2049 ];

  networking.extraHosts = ''
    ${kubeMasterIP} ${kubeMasterHostname}
    192.168.1.4 nixos-desktop
  '';

  # Avahi config
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
} 

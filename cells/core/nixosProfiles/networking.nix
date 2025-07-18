# cells/core/nixosProfiles/networking.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  networking.hostName = "nixos";
  networking.domain = "shinbunbun.com";
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  networking.interfaces.wlp1s0.useDHCP = false;
  networking.enableIPv6 = true;

  networking.firewall.allowedTCPPorts = [
    8888 # General purpose
  ];

  networking.extraHosts = ''
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

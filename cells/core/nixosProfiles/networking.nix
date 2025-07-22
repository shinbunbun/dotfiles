# cells/core/nixosProfiles/networking.nix
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
  networking.hostName = cfg.networking.hosts.nixos.hostname;
  networking.domain = cfg.networking.hosts.nixos.domain;
  networking.useDHCP = false;
  networking.interfaces.${cfg.networking.interfaces.primary}.useDHCP = true;
  networking.interfaces.${cfg.networking.interfaces.wireless}.useDHCP = false;
  networking.enableIPv6 = true;

  networking.firewall.allowedTCPPorts = [
    cfg.networking.firewall.generalPort # General purpose
  ];

  networking.extraHosts = ''
    ${cfg.networking.hosts.nixosDesktop.ip} ${cfg.networking.hosts.nixosDesktop.hostname}
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

# cells/core/nixosProfiles/nfs.nix
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
  # NFS server configuration
  services.nfs.server.enable = true;
  services.nfs.server.exports = lib.concatMapStringsSep "\n" 
    (client: "${cfg.nfs.exportPath}  ${client.ip}(${cfg.nfs.options})") 
    cfg.nfs.clients;

  # Open NFS port in firewall
  networking.firewall.allowedTCPPorts = [
    cfg.networking.firewall.nfsPort # NFS
  ];
}

# cells/core/nixosProfiles/nfs.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # NFS server configuration
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /export/k8s  192.168.1.4(rw,nohide,insecure,no_subtree_check,no_root_squash)
    /export/k8s  192.168.1.3(rw,nohide,insecure,no_subtree_check,no_root_squash)
  '';

  # Open NFS port in firewall
  networking.firewall.allowedTCPPorts = [
    2049 # NFS
  ];
}

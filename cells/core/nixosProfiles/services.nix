# cells/core/nixosProfiles/services.nix
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
  # SSH service
  services.openssh = {
    enable = true;
    ports = [ cfg.ssh.port ];
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    extraConfig = ''
      AuthorizedKeysFile ${cfg.ssh.authorizedKeysPath}
    '';
  };

  # Fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    ignoreIP = cfg.fail2ban.ignoreNetworks;
  };

  # Docker
  virtualisation.docker.enable = true;
}

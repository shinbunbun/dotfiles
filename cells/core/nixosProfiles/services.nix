# cells/core/nixosProfiles/services.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # SSH service
  services.openssh = {
    enable = true;
    ports = [ 31415 ];
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    extraConfig = ''
      AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
    '';
  };

  # Fail2ban for SSH protection
  services.fail2ban = {
    enable = true;
    ignoreIP = [
      "192.168.11.0/24"
      "163.143.0.0/16"
    ];
  };

  # Docker
  virtualisation.docker.enable = true;
}

# cells/core/nixosProfiles/security.nix
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
  # PAM設定
  security.pam.services = {
    sudo.sshAgentAuth = true;
  };

  # Polkit
  security.polkit.enable = true;

  # SOPS設定
  sops = {
    defaultSopsFile = "${inputs.self}/secrets/ssh-keys.yaml";
    age.keyFile = cfg.sops.keyFile;

    secrets."ssh_keys/bunbun" = {
      path = "/etc/ssh/authorized_keys.d/bunbun";
      owner = "bunbun";
      group = "wheel";
      mode = "0444";
      neededForUsers = true;
    };
  };
}

# cells/core/nixosProfiles.nix
{ inputs, cell }:
{
  default = { config, pkgs, lib, ... }: let
    base = import ./base.nix { inherit config pkgs lib; };
  in
  base // {
    sops = {
      defaultSopsFile = ../secrets/ssh-keys.yaml;
      age.keyFile = "/var/lib/sops-nix/key.txt";
      secrets."ssh_keys/bunbun" = {
        owner = "bunbun";
      };
    };
    users.users.bunbun.openssh.authorizedKeys.keyFiles = [
      config.sops.secrets."ssh_keys/bunbun".path
    ];
  };
  optimise = {
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}

# cells/core/ciNixosProfiles.nix
{ inputs, cell }:
{
  default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      base = import ./base.nix { inherit config pkgs lib; };
    in
    base
    // {
      # sops/sops-nixのimport・設定は一切なし
      users.users.bunbun.openssh.authorizedKeys.keyFiles = [ ];
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

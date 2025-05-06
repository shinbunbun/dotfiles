# cells/core/ciNixosProfiles.nix
{ inputs, cell }:
{
  ciMachine = { config, pkgs, lib, ... }: {
    imports = [ ./base.nix ];
    
    # ユーザー設定
    users.users.bunbun = {
      isNormalUser = true;
      group = "bunbun";
      openssh.authorizedKeys.keyFiles = [ ];
    };
    users.groups.bunbun = {};

    # 最適化設定
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}

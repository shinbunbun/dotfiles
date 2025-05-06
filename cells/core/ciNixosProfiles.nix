# cells/core/ciNixosProfiles.nix
{ inputs, cell }:
{
  ciMachine = { config, pkgs, lib, ... }: {
    # 基本的なシステム設定
    system.stateVersion = "24.05";
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # ブートローダーの設定
    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # ネットワーク設定
    networking = {
      hostName = "ciMachine";
      useDHCP = true;
      firewall.enable = false;
    };

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

    # VMビルドの設定
    virtualisation.vmVariantWithBootLoader = {
      virtualisation = {
        memorySize = 2048;
        cores = 2;
        graphics = false;
      };
    };
  };
}

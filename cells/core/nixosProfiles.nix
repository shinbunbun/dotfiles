# cells/core/nixosProfiles.nix
{ inputs, cell }:
let
  isVM = builtins.getEnv "NIXOS_BUILD_VM" == "1";
in
{
  default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      base = import ./base.nix {
        inherit
          config
          pkgs
          lib
          inputs
          ;
      };
    in
    base
  /*
    // lib.mkIf (builtins.getEnv "CI" == "") {
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
    }
    // lib.mkIf (builtins.getEnv "CI" != "") {
      virtualisation.vmVariantWithBootLoader = {
        virtualisation = {
          memorySize = 2048;
          cores = 2;
          graphics = false;
        };
      };
    }
  */
  ;
  optimise = {
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  vm =
    {
      lib,
      ...
    }:
    {
      boot.initrd.availableKernelModules = lib.mkDefault (
        if isVM then
          [
            "virtio_pci"
            "virtio_blk"
          ]
        else
          [ ]
      );

      # ルートファイルシステムも VM なら /dev/vda1 を使う
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "ext4";
      };

      # /boot EFI パーティション
      fileSystems."/boot" = {
        device = "/dev/vda2";
        fsType = "vfat";
      };
    };
}

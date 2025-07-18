# cells/core/nixosProfiles.nix
{ inputs, cell }:
{
  # 分割されたモジュール
  base = import ./nixosProfiles/base.nix { inherit inputs cell; };
  networking = import ./nixosProfiles/networking.nix { inherit inputs cell; };
  services = import ./nixosProfiles/services.nix { inherit inputs cell; };
  security = import ./nixosProfiles/security.nix { inherit inputs cell; };
  kubernetes = import ./nixosProfiles/kubernetes.nix { inherit inputs cell; };
  systemTools = import ./nixosProfiles/system-tools.nix { inherit inputs cell; };

  # 既存のモジュール
  obsidian-livesync = import ./nixosProfiles/obsidian-livesync.nix { inherit inputs cell; };
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
      boot.initrd.availableKernelModules = lib.mkDefault [
        "virtio_pci"
        "virtio_blk"
      ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos-root";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/nixos-boot";
        fsType = "vfat";
      };
    };

  # 互換性のためのdefaultプロファイル（全モジュールを統合）
  default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        cell.nixosProfiles.base
        cell.nixosProfiles.networking
        cell.nixosProfiles.services
        cell.nixosProfiles.security
        cell.nixosProfiles.kubernetes
        cell.nixosProfiles.systemTools
      ];
    };
}

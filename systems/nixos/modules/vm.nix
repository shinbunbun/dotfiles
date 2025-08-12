/*
  VM設定

  仮想マシン環境用の基本設定を提供します。
  CI環境やテスト環境で使用されます。
*/
{
  config,
  lib,
  pkgs,
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
}

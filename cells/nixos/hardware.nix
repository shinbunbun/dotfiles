{ config, pkgs, ... }:

{
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Include the results of the hardware scan.
  imports = [ ./hardware-configuration-nixos.nix ];
} 

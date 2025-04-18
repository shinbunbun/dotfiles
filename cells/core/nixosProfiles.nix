{
  inputs,
  cell,
}:
{
  default = {
    # This value determines the NixOS release
    system.stateVersion = "21.11";

    # Auto upgrade
    system.autoUpgrade.enable = true;
    system.autoUpgrade.allowReboot = false;

    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    # Use the systemd-boot EFI boot loader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };

  optimise = {
    # https://wiki.nixos.org/wiki/Storage_optimization
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}

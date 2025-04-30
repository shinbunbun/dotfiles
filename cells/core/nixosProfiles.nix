{
  inputs,
  cell,
}:
{
  default = let
    kubeMasterIP = "192.168.1.3";
    kubeMasterHostname = "api.kube";
  in  {
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

    networking.hostName = "nixos";
    networking.useDHCP = false;
    networking.interfaces.eno1.useDHCP = true;
    networking.interfaces.wlp1s0.useDHCP = false;
    networking.enableIPv6 = true;

    # Open ports in the firewall.
    networking.firewall.allowedTCPPorts = [
      6443
      8888
      2049
    ];

    networking.extraHosts = ''
      ${kubeMasterIP} ${kubeMasterHostname}
      192.168.1.4 nixos-desktop
    '';

    # Avahi config
    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
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

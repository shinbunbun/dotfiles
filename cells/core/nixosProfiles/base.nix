# cells/core/nixosProfiles/base.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  configValues = import ../config.nix;
in
{
  system.stateVersion = configValues.system.nixosStateVersion;
  system.autoUpgrade.enable = false;
  system.autoUpgrade.allowReboot = false;

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = configValues.system.timeZone;

  users.users.bunbun = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    # authorizedKeys.keyFilesはprofileごとに上書き
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
  ];

  virtualisation = {
    vmVariantWithBootLoader = {
      virtualisation = {
        memorySize = 2048;
        cores = 2;
        graphics = false;
        useEFIBoot = true;
      };
    };
  };
}

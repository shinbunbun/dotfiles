/*
  基本的なNixOS設定モジュール

  このモジュールは以下の基本的なシステム設定を提供します：
  - システムステートバージョンの管理
  - Flakesサポートを含むNixデーモンの設定
  - コアユーザーとグループの管理
  - 基本的なシステムパッケージ（git、vim、neovim）
  - システム全体のGit設定
  - タイムゾーン設定

  このモジュールは通常、すべてのNixOS設定の基盤として含まれます。
*/
{
  config,
  pkgs,
  lib,
  ...
}:

let
  configValues = import ../../../shared/config.nix;
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

  # NTPサービスの設定（systemd-timesyncd）
  services.timesyncd = {
    enable = true;
    servers = [
      "ntp.nict.jp"
      "ntp.jst.mfeed.ad.jp"
      "ntp1.jst.mfeed.ad.jp"
    ];
  };

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

  environment.systemPackages = [
    pkgs.vim
    pkgs.wget
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

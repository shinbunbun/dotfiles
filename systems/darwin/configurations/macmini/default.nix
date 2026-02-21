/*
  Darwin設定 - macmini

  Mac Mini用のmacOSシステム設定を定義します。
  MacBookと比較して以下の違いがあります：
  - WireGuardは不要
  - Homebrewパッケージは最小限（Claude, Google Chrome, Xcode のみ）
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = import ../../../../shared/config.nix;
  username = cfg.users.darwin.username;
in
{
  imports = [
    # 基本モジュール
    ../../modules/base.nix
    ../../modules/optimise.nix
    # WireGuardは不要

    # 外部モジュール
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops
  ];

  # ホスト名設定
  networking.hostName = cfg.networking.hosts.macmini.hostname;
  networking.computerName = cfg.networking.hosts.macmini.hostname;
  networking.localHostName = cfg.networking.hosts.macmini.hostname;

  # SSH（Remote Login）有効化
  services.openssh.enable = true;

  # SSHセキュリティ設定（パスワード認証無効化、公開鍵認証のみ）
  services.openssh.extraConfig = ''
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AuthorizedKeysFile ${cfg.ssh.authorizedKeysPath}
  '';

  # SOPS設定（SSH公開鍵の復号）
  sops = {
    defaultSopsFile = "${inputs.self}/secrets/ssh-keys.yaml";
    age.keyFile = cfg.sops.keyFile;

    secrets."ssh_keys/bunbun" = {
      path = "/etc/ssh/authorized_keys.d/${username}";
      mode = "0444";
    };
  };

  # Nixpkgs設定
  nixpkgs.config.allowUnfree = true;

  # Homebrew設定（最小限）
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    casks = [
      "claude" # Claude AIアシスタント
      "google-chrome" # Webブラウザ
    ];
    masApps = {
      "Xcode" = 497799835;
    };
  };

  # Home Manager設定
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.${username} = import ../../../../home/profiles/shinbunbun;
  };
}

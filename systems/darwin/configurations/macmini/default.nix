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

    # 監視・ログ収集
    ../../modules/node-exporter.nix
    ../../modules/fluent-bit.nix

    # 外部モジュール
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops

    # GitHub Actions Self-Hosted Runner
    ./github-runner.nix
  ];

  # ホスト名設定
  networking.hostName = cfg.networking.hosts.macmini.hostname;
  networking.computerName = cfg.networking.hosts.macmini.hostname;
  networking.localHostName = cfg.networking.hosts.macmini.hostname;

  # 電源管理設定（ヘッドレス運用のためスリープ無効化）
  power.sleep.computer = "never";
  power.sleep.display = "never";
  power.sleep.harddisk = "never";

  # SSH（Remote Login）有効化
  services.openssh.enable = true;

  # SSHセキュリティ設定（パスワード認証無効化、公開鍵認証のみ）
  services.openssh.extraConfig = ''
    PasswordAuthentication no
    KbdInteractiveAuthentication no
  '';

  # Mosh（Mobile Shell）パッケージ
  environment.systemPackages = [
    pkgs.mosh
  ];

  # SSH公開鍵認証（nix-darwinのAuthorizedKeysCommand経由で配置）
  users.users.${username}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPsh7m83p/bIrnzDVYUTzNfw9OAgVH1nu80Qg2TElgVL"
  ];

  # SOPS設定（Atticプライベートキャッシュ用netrc）
  sops = {
    defaultSopsFile = "${inputs.self}/secrets/nix.yaml";
    age.keyFile = cfg.sops.keyFile;
    age.sshKeyPaths = [ ];

    secrets."nix_netrc" = {
      mode = "0444";
    };
  };

  # プライベートキャッシュの認証用netrc
  nix.settings.netrc-file = config.sops.secrets."nix_netrc".path;

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
      "claude-code" # Claude Code CLIツール
      "google-chrome" # Webブラウザ
      "warp" # ターミナル
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

/*
  Darwin設定 - macbook

  macOSシステムの設定を定義します。
  必要なモジュールをインポートし、システム固有の設定を行います。
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
    ../../modules/wireguard.nix

    # 外部モジュール
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops
  ];

  # Nixpkgs設定
  nixpkgs.config.allowUnfree = true;

  # Touch IDを使用したsudo認証
  security.pam.services.sudo_local.touchIdAuth = true;

  # Homebrew設定
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    brews = [
      # 開発ツール
      "go" # Goプログラミング言語
      "nvm" # Node.jsバージョンマネージャー

      # CLIツール
      "jq" # JSONプロセッサ
      "yq" # YAMLプロセッサ
      "yamllint" # YAMLリンター
      "mas" # Mac App Store CLI
    ];
    casks = [
      # 開発ツール
      "cursor" # AIパワードエディタ
      "copilot-for-xcode" # GitHub Copilot for Xcode
      "graphql-playground" # GraphQLクライアント
      "altair-graphql-client" # GraphQLクライアント
      "xquartz" # X11サーバー

      # 生産性ツール
      "obsidian" # ナレッジマネジメント
      "claude" # Claude AIアシスタント
      "claude-code" # Claude Code CLIツール
      "warp" # ターミナル

      # クリエイティブツール
      "adobe-creative-cloud" # Adobe Creative Cloud

      # コミュニケーション
      "discord" # Discordチャット

      # ユーティリティ
      "vnc-viewer" # VNCクライアント
      "1password"
      "vlc"
    ];
    masApps = {
      # Apple製アプリ
      "GarageBand" = 682658836;
      "iMovie" = 408981434;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;

      # Microsoft Office
      "Microsoft Excel" = 462058435;
      "Microsoft OneNote" = 784801555;
      "Microsoft Outlook" = 985367838;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      "OneDrive" = 823766827;

      # 生産性ツール
      "Goodnotes" = 1444383602;
      "Spark" = 1176895641;

      # コミュニケーション
      "LINE" = 539883307;
      "Slack for Desktop" = 803453959;

      # 開発ツール
      "Xcode" = 497799835;

      # ユーティリティ
      "Brother iPrint&Scan" = 1193539993;
      "CommentScreen" = 1450950860;
      "RunCat" = 1429033973;
      "WireGuard" = 1451685025;
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

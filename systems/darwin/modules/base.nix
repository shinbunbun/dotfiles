/*
  Darwin基本設定モジュール

  macOSシステムの基本設定を提供します：
  - システムバージョン設定
  - Nix設定（sandbox、trusted-users）
  - Touch IDを使用したsudo認証
  - Homebrew設定
*/
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = import ../../../shared/config.nix;
in
{
  system.stateVersion = 5;
  system.primaryUser = cfg.users.darwin.username;

  nix.settings = {
    # macOS推奨: Fixed-output derivations（npm依存関係など）をサンドボックスから除外
    # これによりDNS解決とネットワークアクセスが正常に動作する
    sandbox = "relaxed";
    trusted-users = [ "@admin" ];
    allowed-users = [ "@admin" ];
  };

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  security.pam.services.sudo_local.touchIdAuth = true;

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
    };
  };
}

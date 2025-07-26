/*
  Darwin（macOS）プロファイルモジュール

  このモジュールはmacOS用の設定プロファイルを提供します：
  - default: 基本的なmacOS設定
    - システム設定（stateVersion、ユーザー名）
    - Nix設定（sandbox、trusted-users）
    - Touch IDを使用したsudo認証
    - Homebrew設定（パッケージ、Cask、Mac App Storeアプリ）
  - optimize: ストレージ最適化設定
    - Nixストアの自動最適化
    - 週次のガベージコレクション
  - wireguard: WireGuard VPN設定
    - SOPSを使用した鍵管理
    - sops-wireguardヘルパーを使用した設定
*/
{
  inputs,
  cell,
}:
{
  default = {
    system.stateVersion = 5;

    system.primaryUser = "shinbunbun";

    nix.settings.sandbox = true;
    nix.settings.trusted-users = [ "@admin" ];
    nix.settings.allowed-users = [ "@admin" ];
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
  };

  optimize = {
    # https://wiki.nixos.org/wiki/Storage_optimization

    nix.optimise.automatic = true;
    nix.gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 0;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  wireguard =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      sopsWireGuardHelper = import ./sops-wireguard.nix { inherit inputs cell; };
      cfg = import ./config.nix;
    in
    sopsWireGuardHelper.mkSopsWireGuardConfig { inherit config pkgs lib; } {
      sopsFile = "${inputs.self}/secrets/wireguard.yaml";
      privateKeyPath = cfg.wireguard.darwin.privateKeyPath;
      publicKeyPath = cfg.wireguard.darwin.publicKeyPath;
      endpointPath = cfg.wireguard.darwin.endpointPath;
      interfaceName = cfg.wireguard.darwin.interfaceName;
      interfaceAddress = "${cfg.wireguard.darwin.clientIp}/32";
      peerAllowedIPs = cfg.wireguard.darwin.allowedNetworks ++ [ "${cfg.wireguard.network.serverIp}/32" ];
      persistentKeepalive = cfg.wireguard.persistentKeepalive;
      isDarwin = true;
    }
    // {
      # Darwin用のSOPS基本設定
      sops = {
        defaultSopsFile = "${inputs.self}/secrets/wireguard.yaml";
        age.keyFile = cfg.sops.keyFile;
      };
    };
}

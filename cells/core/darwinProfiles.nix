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
        "go"
        "jq"
        "yamllint"
        "nvm"
        "yq"
        "mas"
      ];
      casks = [
        "graphql-playground"
        "altair-graphql-client"
        "cursor"
        "copilot-for-xcode"
        "adobe-creative-cloud"
        "xquartz"
        "discord"
        "vnc-viewer"
        "claude"
        "obsidian"
      ];
      masApps = {
        "Brother iPrint&Scan" = 1193539993;
        "CommentScreen" = 1450950860;
        "GarageBand" = 682658836;
        "Goodnotes" = 1444383602;
        "iMovie" = 408981434;
        "Keynote" = 409183694;
        "LINE" = 539883307;
        "Microsoft Excel" = 462058435;
        "Microsoft OneNote" = 784801555;
        "Microsoft Outlook" = 985367838;
        "Microsoft PowerPoint" = 462062816;
        "Microsoft Word" = 462054704;
        "Numbers" = 409203825;
        "OneDrive" = 823766827;
        "Pages" = 409201541;
        "RunCat" = 1429033973;
        "Spark" = 1176895641;
        "Xcode" = 497799835;
        "Slack for Desktop" = 803453959;
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

/*
  Nix Flakeエントリポイント

  このflakeは以下の機能を提供します：
  - NixOSシステム設定
  - Darwin（macOS）システム設定
  - home-manager設定
  - 開発シェル環境

  std/hiveへの依存を削除し、標準的なflake構造を採用しています。

  使用方法:
  - nixos-rebuild switch --flake .#<hostname>
  - darwin-rebuild switch --flake .#<hostname>
  - nix develop
*/
{
  description = "nix-dotfiles-template";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
    };

    # nixos-observability
    nixos-observability = {
      url = "github:shinbunbun/nixos-observability";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos-observability-config
    nixos-observability-config = {
      url = "github:shinbunbun/nixos-observability-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # deploy-rs
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Attic binary cache
    # Note: nixpkgs.followsを削除してattic自身のnixpkgsを使用
    # 理由: 最新のNix 2.31.3との互換性問題を回避するため
    attic = {
      url = "github:zhaofengli/attic";
    };

    # peer-issuer: WireGuard peer動的発行API
    peer-issuer = {
      url = "github:shinbunbun/peer-issuer";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # claude-code: Claude Code CLIツール（Nix native binary）
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      devshell,
      sops-nix,
      vscode-server,
      flake-utils,
      nixos-observability,
      nixos-observability-config,
      deploy-rs,
      attic,
      peer-issuer,
      claude-code,
      ...
    }@inputs:
    let
      # サポートするシステムのリスト
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # nixpkgsの共通設定
      nixpkgsConfig = {
        allowUnfree = true;
      };

      # システムごとの関数を作成
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      # システムごとのpkgsを取得
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config = nixpkgsConfig;
        };
    in
    {
      # NixOS設定
      nixosConfigurations = {
        homeMachine = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./systems/nixos/configurations/homeMachine/default.nix
          ];
        };
      };

      # Darwin設定
      darwinConfigurations = {
        macbook = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./systems/darwin/configurations/macbook/default.nix
          ];
        };
        macmini = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            ./systems/darwin/configurations/macmini/default.nix
          ];
        };
      };

      # 開発シェル
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = import ./devshell { inherit pkgs inputs; };
        }
      );

      # フォーマッター
      formatter = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.nixfmt-tree
      );

      # NixOS モジュールを export（dotfiles-private から利用可能）
      nixosModules = {
        # Base modules
        base = ./systems/nixos/modules/base.nix;
        desktop = ./systems/nixos/modules/desktop.nix;
        security = ./systems/nixos/modules/security.nix;
        optimise = ./systems/nixos/modules/optimise.nix;
        system-tools = ./systems/nixos/modules/system-tools.nix;
        networking = ./systems/nixos/modules/networking.nix;
        wireguard = ./systems/nixos/modules/wireguard.nix;
        nfs = ./systems/nixos/modules/nfs.nix;
        k3s = ./systems/nixos/modules/k3s.nix;
        vm = ./systems/nixos/modules/vm.nix;

        # Service modules
        services = {
          monitoring = ./systems/nixos/modules/services/monitoring.nix;
          loki = ./systems/nixos/modules/services/loki.nix;
          cockpit = ./systems/nixos/modules/services/cockpit.nix;
          ttyd = ./systems/nixos/modules/services/ttyd.nix;
          opensearch = ./systems/nixos/modules/services/opensearch.nix;
          opensearch-dashboards = ./systems/nixos/modules/services/opensearch-dashboards.nix;
          fluent-bit = ./systems/nixos/modules/services/fluent-bit.nix;
          authentik = ./systems/nixos/modules/services/authentik.nix;
          obsidian-livesync = ./systems/nixos/modules/services/obsidian-livesync.nix;
          routeros-backup = ./systems/nixos/modules/services/routeros-backup.nix;
          unified-cloudflare-tunnel = ./systems/nixos/modules/services/unified-cloudflare-tunnel.nix;
          desktop-cloudflare-tunnel = ./systems/nixos/modules/services/desktop-cloudflare-tunnel.nix;
          alertmanager = ./systems/nixos/modules/services/alertmanager.nix;
          attic = ./systems/nixos/modules/services/attic.nix;
          peer-issuer = ./systems/nixos/modules/services/peer-issuer.nix;
          deploy-user = ./systems/nixos/modules/services/deploy-user.nix;
          argocd = ./systems/nixos/modules/services/argocd.nix;
          mosh = ./systems/nixos/modules/services/mosh.nix;
        };
      };

      # 共通設定も export（オプション）
      lib = {
        config = import ./shared/config.nix;
      };

      # deploy-rs設定
      deploy.nodes = {
        homeMachine = {
          hostname = "homemachine"; # SSH config の Host名（WireGuard VPN経由）
          fastConnection = false; # WireGuard VPN経由なのでfalse
          interactiveSudo = false;
          remoteBuild = true; # リモートマシンでビルド（deployユーザーはtrusted-user）

          profiles.system = {
            sshUser = "deploy"; # デプロイ専用ユーザー
            path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.homeMachine;
            user = "root";
          };
        };
      };

      # deploy-rs checks（デプロイ先がx86_64-linuxのみのため、該当システムに限定）
      checks."x86_64-linux" = deploy-rs.lib.x86_64-linux.deployChecks self.deploy;
    };
}

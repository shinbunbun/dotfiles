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

    # nixos-observability（ローカル開発用）
    nixos-observability = {
      url = "path:/home/bunbun/nixos-observability";
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

      # パッケージ（将来の拡張用）
      packages = forAllSystems (system: { });

      # アプリケーション（将来の拡張用）
      apps = forAllSystems (system: { });

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
        kubernetes = ./systems/nixos/modules/kubernetes.nix;
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
        };
      };

      # 共通設定も export（オプション）
      lib = {
        config = import ./shared/config.nix;
      };
    };
}

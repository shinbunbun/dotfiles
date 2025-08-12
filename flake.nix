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

    flake-utils = {
      url = "github:numtide/flake-utils";
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
      flake-utils,
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
    };
}


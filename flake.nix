/*
  Nix Flakeエントリポイント

  このflakeは以下の機能を提供します：
  - NixOSシステム設定
  - Darwin（macOS）システム設定
  - home-manager設定
  - 開発シェル環境

  std（Standard）フレームワークを使用して、
  モジュラーな設定構造を実現しています。

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

    std = {
      url = "github:divnix/std";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.devshell.follows = "devshell";
    };

    hive = {
      url = "github:shinbunbun/hive?ref=shinbunbun";
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
      std,
      hive,
      flake-utils,
      ...
    }@inputs:
    let
      base =
        std.growOn
          {
            inherit inputs;
            nixpkgsConfig = {
              allowUnfree = true;
            };
            systems = [
              "x86_64-linux"
              "aarch64-linux"
              "x86_64-darwin"
              "aarch64-darwin"
            ];
            cellsFrom = ./cells;
            cellBlocks =
              with std.blockTypes;
              with hive.blockTypes;
              [
                (functions "nixosProfiles")
                (functions "darwinProfiles")
                (functions "homeProfiles")
                (
                  nixosConfigurations
                  // {
                    ci.build-vm-with-bootloader = true;
                    ci.build = true;
                  }
                )
                (darwinConfigurations // { ci.build = true; })
                (devshells "shells" { ci.build = true; })
              ];
          }
          {
            nixosConfigurations = hive.collect self "nixosConfigurations";
            darwinConfigurations = hive.collect self "darwinConfigurations";
            devShells = hive.harvest self [
              "repo"
              "shells"
            ];
          };
      formatter = flake-utils.lib.eachDefaultSystemMap (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.nixfmt-tree
      );
    in
    base // { inherit formatter; };
}

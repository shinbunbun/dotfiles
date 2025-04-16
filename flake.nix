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
      url = "github:divnix/hive";
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
    # ① growOn で各種セルを展開
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
            cellBlocks = [
              (std.blockTypes.functions "nixosProfiles")
              (std.blockTypes.functions "darwinProfiles")
              (std.blockTypes.functions "homeProfiles")
              (hive.blockTypes.nixosConfigurations)
              (hive.blockTypes.darwinConfigurations // { ci.build = true; })
              (std.blockTypes.devshells "shells" { ci.build = true; })
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
      # ② growOn の結果に formatter をマージ
    in
    base
    // {
      formatter = flake-utils.lib.eachDefaultSystemMap (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.nixfmt-tree
      );
    };
}

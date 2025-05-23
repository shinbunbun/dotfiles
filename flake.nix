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
      # url = "github:divnix/hive";
      # url = "/Users/shinbunbun/hive";
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
    # ① growOn で各種セルを展開
    # let
    # customSelf = self // { renamer = cell: target: target; };
    # base =
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
                # (hive.blockTypes.nixosConfigurations)
                # (darwinConfigurations // { ci.build = true; })
                # (devshells "shells" { ci.build = true; })
                /*
                  (
                    nixosConfigurations
                    // {
                      ci.build = true;
                      transform =
                        config:
                        config
                        // {
                          targetDrv = config.config.system.build.toplevel;
                        };
                    }
                  )
                */
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
            # nixosConfigurations = hive.collect.__functor customSelf customSelf "nixosConfigurations";
            /*
              nixosConfigurations =
              let
                collected = hive.collect self "nixosConfigurations";
              in
              builtins.mapAttrs (
                name: config:
                config
                // {
                  # targetDrv = builtins.trace "nixosConfigurations: ${builtins.typeOf (config.config.system.build.toplevel)}" config.config.system.build.toplevel;
                  targetDrv = config.config.system.build.toplevel;
                }
              ) collected;
            */
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

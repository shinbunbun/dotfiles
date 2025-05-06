# outputs.nixosConfigurations.homeMachine.config.system.build.toplevelにbuildが存在している
# nix build .#nixosConfigurations.homeMachine.config.system.build.toplevelでは成功する
# ファイルを変更したので nix build .#nixosConfigurations.toplevel-homeMachine.config.system.build.toplevel

{
  inputs,
  cell,
}:
{
  # homeMachine = {
  #   bee = {
  #     system = "x86_64-linux";
  #     pkgs = inputs.nixpkgs;
  #     # home = inputs.home-manager;
  #   };

  #   /*
  #     meta = {
  #       description = "Home machine NixOS configuration";
  #     };
  #   */

  #   imports = [
  #     ./hardwareConfigurations/homeMachine.nix
  #     inputs.cells.core.nixosProfiles.default
  #     inputs.cells.core.nixosProfiles.optimise
  #     inputs.sops-nix.nixosModules.sops
  #   ];

  #   ci.build = false;
  # };

  ciMachine = {
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
      # home = inputs.home-manager;
    };

    imports = [
      ./hardwareConfigurations/homeMachine.nix
      inputs.cells.core.ciNixosProfiles.ciMachine
    ];

    # VMビルドの設定
    virtualisation.vmVariant = {
      virtualisation = {
        memorySize = 2048;
        cores = 2;
        graphics = false;
      };
    };

    # VMビルドの設定
    system.build = {
      vmWithBootLoader = inputs.nixpkgs.lib.mkForce (inputs.nixpkgs.lib.mkVMOverride {
        inherit (inputs.nixpkgs.lib) mkForce;
      });
    };
  };
}

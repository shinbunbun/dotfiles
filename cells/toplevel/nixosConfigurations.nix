# outputs.nixosConfigurations.homeMachine.config.system.build.toplevelにbuildが存在している
# nix build .#nixosConfigurations.homeMachine.config.system.build.toplevelでは成功する
# ファイルを変更したので nix build .#nixosConfigurations.toplevel-homeMachine.config.system.build.toplevel

{
  inputs,
  cell,
}:
let
  isVM = builtins.getEnv "NIXOS_BUILD_VM" == "1";
in
{
  homeMachine = {
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
      home = inputs.home-manager;
    };

    /*
      meta = {
        description = "Home machine NixOS configuration";
      };
    */

    imports =
      [
        inputs.cells.core.nixosProfiles.default
        inputs.cells.core.nixosProfiles.optimise
        inputs.sops-nix.nixosModules.sops
      ]
      ++ (
        if isVM then
          [
            inputs.cells.core.nixosProfiles.vm
          ]
        else
          [
            ./hardwareConfigurations/homeMachine.nix
          ]
      );
  };

  # ciMachine = {
  #   bee = {
  #     system = "x86_64-linux";
  #     pkgs = inputs.nixpkgs;
  #   };

  #   imports = [
  #     ./hardwareConfigurations/homeMachine.nix
  #     inputs.cells.core.ciNixosProfiles.ciMachine
  #   ];

  # };
}

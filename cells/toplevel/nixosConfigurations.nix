{
  inputs,
  cell,
}:
{
  homeMachine = { config, pkgs, lib, ... }: {
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
    };

    imports = [
      ./hardwareConfigurations/homeMachine.nix
      inputs.cells.core.nixosProfiles.default
      inputs.cells.core.nixosProfiles.optimise
    ];
  };
}

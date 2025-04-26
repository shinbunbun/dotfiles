{
  inputs,
  cell,
}:
{
  homeMachine =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      bee = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        pkgs = inputs.nixpkgs;
      };

      meta = {
        description = "Home machine NixOS configuration";
      };

      imports = [
        ./hardwareConfigurations/homeMachine.nix
        inputs.cells.core.nixosProfiles.default
        inputs.cells.core.nixosProfiles.optimise
      ];
    };
  
  default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      bee = {
        system = "x86_64-linux";
        pkgs = inputs.nixpkgs;
      };

      meta = {
        description = "Default NixOS configuration";
      };

      imports = [
        ./hardwareConfigurations/homeMachine.nix
        inputs.cells.core.nixosProfiles.default
        inputs.cells.core.nixosProfiles.optimise
      ];
    };
}

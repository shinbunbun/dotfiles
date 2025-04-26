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
      bee = {
        system = "x86_64-linux";
        pkgs = inputs.nixpkgs;
        # home = inputs.home-manager;
      };

      /* meta = {
        description = "Home machine NixOS configuration";
      }; */

      imports = [
        # ./hardwareConfigurations/homeMachine.nix
        inputs.cells.core.nixosProfiles.default
        inputs.cells.core.nixosProfiles.optimise
      ];
    };
}

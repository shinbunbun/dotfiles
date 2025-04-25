{
  inputs,
  cell,
}:
{
  homeMachine = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./hardwareConfigurations/homeMachine.nix
      inputs.cells.core.nixosProfiles.default
      inputs.cells.core.nixosProfiles.optimise
    ];
  };
}

{
  inputs,
  cell,
}:
{
  homeMachine = inputs.nixpkgs.lib.nixosSystem {
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
    };

    imports = [
      inputs.cells.core.nixosProfiles.default
      inputs.cells.core.nixosProfiles.optimise
    ];
  };

  __std.actions = {
    homeMachine = {
      build = cell.nixosConfigurations.homeMachine.config.system.build.toplevel;
    };
  };
}

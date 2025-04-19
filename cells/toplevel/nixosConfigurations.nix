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
      inputs.cells.core.nixosProfiles.default
      inputs.cells.core.nixosProfiles.optimise
    ];

    __std.actions.build = config.system.build.toplevel;
  };
}

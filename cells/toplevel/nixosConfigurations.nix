{
  inputs,
  cell,
}:
{
  nixos = {
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
    };

    imports = [
      inputs.cells.core.nixosProfiles.default
    ];
  };
}

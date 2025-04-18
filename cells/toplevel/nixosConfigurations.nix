{
  inputs,
  cell,
}:
{
  nixos = {
    bee = {
      system = inputs.nixpkgs.system;
      pkgs = inputs.nixpkgs;
    };

    imports = [
      inputs.sops-nix.nixosModules.sops
      inputs.cells.nixos.nixosProfiles.default
    ];
  };
}

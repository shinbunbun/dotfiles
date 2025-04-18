{
  inputs,
  cell,
}:
{
  nixos = {
    system = "x86_64-linux";
    bee = {
      pkgs = inputs.nixpkgs;
    };

    imports = [
      inputs.sops-nix.nixosModules.sops
      inputs.cells.nixos.nixosProfiles.default
    ];
  };
}

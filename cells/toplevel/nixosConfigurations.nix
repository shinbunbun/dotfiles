{
  inputs,
  cell,
}:
{
  nixos = {
    system = "x86_64-linux";
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
    };

    imports = [
      inputs.sops-nix.nixosModules.sops
      inputs.cells.nixos.nixosProfiles.default
    ];
  };
}

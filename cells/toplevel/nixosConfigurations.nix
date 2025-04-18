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
      inputs.sops-nix.nixosModules.sops
      cell.nixos.nixosProfiles.default
    ];
  };
}

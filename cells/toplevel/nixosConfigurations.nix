{ inputs, cell }:
{
  nixos = {
    system = "x86_64-linux";
    modules = [
      inputs.sops-nix.nixosModules.sops
      inputs.cells.nixos.nixosProfiles.default
    ];
  };
}

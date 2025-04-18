{
  default =
    { ... }:
    {
      imports = [
        ./hardware.nix
        ./networking.nix
        ./users.nix
        ./services.nix
        ./kubernetes.nix
      ];
    };
}

{
  inputs,
  cell,
}:
let
  l = nixpkgs.lib // builtins;
  inherit (inputs) nixpkgs;
  inherit (inputs.std) std lib;
  darwinPackages =
    if l.hasSuffix "darwin" nixpkgs.system then
      [
        {
          package = inputs.nix-darwin.packages.${nixpkgs.system}.default;
        }
      ]
    else
      [ ];
in
l.mapAttrs (_: lib.dev.mkShell) {
  default = {
    name = "shinbunbun";
    imports = [ std.devshellProfiles.default ];
    commands =
      with nixpkgs;
      [
        { package = alejandra; }
        {
          category = "sops";
          package = age;
        }
        {
          category = "sops";
          package = sops;
        }
        {
          category = "sops";
          package = ssh-to-age;
        }
      ]
      ++ darwinPackages;
  };
}

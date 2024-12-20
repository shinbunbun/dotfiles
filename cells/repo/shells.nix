{
  inputs,
  cell,
}: let
  l = nixpkgs.lib // builtins;
  inherit (inputs) nixpkgs;
  inherit (inputs.std) std lib;
in
  l.mapAttrs (_: lib.dev.mkShell) {
    default = {
      name = "nix-dotfiles-template";
      imports = [ std.devshellProfiles.default ];
      commands = with nixpkgs; [
        { package = alejandra; }
        { category = "sops"; package = age; }
        { category = "sops"; package = sops; }
        { category = "sops"; package = ssh-to-age; }
      ];
    };
  }

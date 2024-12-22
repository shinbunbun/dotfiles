{
  inputs,
  cell,
}: {
  macOS = {
    bee = {
      system = "aarch64-darwin";
      pkgs = inputs.nixpkgs;
      home = inputs.home-manager;
      darwin = inputs.nix-darwin;
    };

    imports = [
      inputs.cells.core.darwinProfiles.default
      inputs.cells.core.darwinProfiles.optimize
    ];

    home-manager.users.yoseio = {
      imports = [
        inputs.cells.core.homeProfiles.default

        inputs.cells.dev.homeProfiles.git
        inputs.cells.dev.homeProfiles.zsh
      ];
    };

    users.users = {
      yoseio = {
        createHome = true;
        home = "/Users/yoseio";
        shell = inputs.nixpkgs.pkgs.zsh;
      };
    };
  };
}

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

    home-manager.users.shinbunbun = {
      imports = [
        inputs.cells.core.homeProfiles.default

        inputs.cells.dev.homeProfiles.git
        inputs.cells.dev.homeProfiles.zsh
        inputs.cells.dev.homeProfiles.vim
        inputs.cells.dev.homeProfiles.google_cloud_sdk

        inputs.cells.shinbunbun.homeProfiles.default
      ];
    };

    users.users = {
      shinbunbun = {
        createHome = true;
        home = "/Users/shinbunbun";
        shell = inputs.nixpkgs.pkgs.zsh;
      };
    };
  };
}

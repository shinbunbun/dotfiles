{
  inputs,
  cell,
}:
let
  username = "shinbunbun";
in
{
  macOS = {
    bee = {
      system = "aarch64-darwin";
      pkgs = inputs.nixpkgs;
      home = inputs.home-manager;
      darwin = inputs.nix-darwin;
    };

    imports = [
      inputs.sops-nix.darwinModules.sops
      inputs.cells.core.darwinProfiles.default
      inputs.cells.core.darwinProfiles.optimize
      inputs.cells.core.darwinProfiles.wireguard
    ];

    home-manager.users.${username} = {
      imports = [
        inputs.cells.core.homeProfiles.default

        inputs.cells.dev.homeProfiles.versionControl
        inputs.cells.dev.homeProfiles.shellTools
        inputs.cells.dev.homeProfiles.editors
        inputs.cells.dev.homeProfiles.cloudTools
        inputs.cells.dev.homeProfiles.securityTools
        inputs.cells.dev.homeProfiles.developmentTools
        inputs.cells.dev.homeProfiles.aiTools

        inputs.cells.shinbunbun.homeProfiles.default
      ];
    };

    users.users = {
      ${username} = {
        name = username;
        home = "/Users/${username}";
        shell = inputs.nixpkgs.pkgs.zsh;
        createHome = true;
      };
    };
  };
}

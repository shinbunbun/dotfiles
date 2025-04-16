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

    imports =
      if builtins.getEnv "CI" != "" then
        [ ]
      else
        [
          inputs.cells.core.darwinProfiles.default
          inputs.cells.core.darwinProfiles.optimize
        ];

    home-manager.users.${username} = {
      imports = [
        inputs.cells.core.homeProfiles.default

        inputs.cells.dev.homeProfiles.git
        inputs.cells.dev.homeProfiles.zsh
        inputs.cells.dev.homeProfiles.vim
        inputs.cells.dev.homeProfiles.google_cloud_sdk
        # inputs.cells.dev.homeProfiles.biome
        # inputs.cells.dev.homeProfiles.graphql

        inputs.cells.shinbunbun.homeProfiles.default
      ];
    };

    users.users = {
      ${username} =
        {
          name = username;
          home = "/Users/${username}";
          shell = inputs.nixpkgs.pkgs.zsh;
        }
        // (
          if builtins.getEnv "CI" != "" then
            {
              # CI環境では最小限の設定のみを適用
              createHome = false;
            }
          else
            {
              createHome = true;
            }
        );
    };
  };
}

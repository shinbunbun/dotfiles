{
  inputs,
  cell,
}:
let
  username = "shinbunbun";
  isCI = builtins.getEnv "CI" != "";
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
      if isCI then
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
          if isCI then
            {
              # CI環境では最小限の設定のみを適用
              createHome = false;
              uid = 1000;
              gid = 1000;
            }
          else
            {
              createHome = true;
            }
        );
    };

    # CI環境では不要な設定を無効化
    services.nix-daemon.enable = !isCI;
    services.activate-system.enable = !isCI;
    nix.gc.enable = !isCI;
    nix.optimise.enable = !isCI;
  };
}

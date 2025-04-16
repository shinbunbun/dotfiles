{
  inputs,
  cell,
}:
let
  username = if builtins.getEnv "CI" != "" then "runner" else "shinbunbun";
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

    users.users =
      if builtins.getEnv "CI" == "" then
        {
          # 本番環境では "shinbunbun" ユーザーを作成
          shinbunbun = {
            createHome = true;
            home = "/Users/shinbunbun";
            shell = inputs.nixpkgs.pkgs.zsh;
          };
        }
      else
        { };
  };
}

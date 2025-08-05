# outputs.nixosConfigurations.homeMachine.config.system.build.toplevelにbuildが存在している
# nix build .#nixosConfigurations.homeMachine.config.system.build.toplevelでは成功する
# ファイルを変更したので nix build .#nixosConfigurations.toplevel-homeMachine.config.system.build.toplevel

{
  inputs,
  cell,
}:
let
  isVM = builtins.getEnv "NIXOS_BUILD_VM" == "1";
  cfg = import ../core/config.nix;
  homeMachineUsername = cfg.users.nixos.username;
in
{
  homeMachine = {
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
      home = inputs.home-manager;
    };

    imports = [
      inputs.cells.core.nixosProfiles.default
      inputs.cells.core.nixosProfiles.optimise
      inputs.cells.core.nixosProfiles.obsidian-livesync
      inputs.cells.core.nixosProfiles.routeros-backup
      inputs.cells.core.nixosProfiles.monitoring
      inputs.cells.core.nixosProfiles.alertmanager
      inputs.cells.core.nixosProfiles.authentik

      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops

      # RouterOSバックアップ設定
      (
        { config, ... }:
        {
          services.routerosBackup = {
            enable = true;
            gitRepo = "git@github.com:shinbunbun/routeros-backups.git"; # GitHubユーザー名を変更してください
          };
        }
      )
    ]
    ++ (
      if isVM then
        [
          inputs.cells.core.nixosProfiles.vm
        ]
      else
        [
          ./hardwareConfigurations/homeMachine.nix
        ]
    );

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${homeMachineUsername} = {
        imports = [
          inputs.cells.core.homeProfiles.default
          inputs.cells.shinbunbun.homeProfiles.default

          inputs.cells.dev.homeProfiles.versionControl
          inputs.cells.dev.homeProfiles.shellTools
          inputs.cells.dev.homeProfiles.editors
          inputs.cells.dev.homeProfiles.securityTools
          inputs.cells.dev.homeProfiles.aiTools
          inputs.cells.dev.homeProfiles.cloudTools
        ];
      };
    };
  };
}

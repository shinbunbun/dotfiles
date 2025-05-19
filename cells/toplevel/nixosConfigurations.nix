# outputs.nixosConfigurations.homeMachine.config.system.build.toplevelにbuildが存在している
# nix build .#nixosConfigurations.homeMachine.config.system.build.toplevelでは成功する
# ファイルを変更したので nix build .#nixosConfigurations.toplevel-homeMachine.config.system.build.toplevel

{
  inputs,
  cell,
}:
let
  isVM = builtins.getEnv "NIXOS_BUILD_VM" == "1";
  homeMachineUsername = "bunbun";
in
{
  homeMachine = {
    bee = {
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs;
      home = inputs.home-manager;
    };

    /*
      meta = {
        description = "Home machine NixOS configuration";
      };
    */

    imports =
      [
        inputs.cells.core.nixosProfiles.default
        inputs.cells.core.nixosProfiles.optimise
        inputs.home-manager.nixosModules.home-manager
      ]
      ++ (
        if isVM then
          # VMビルド用の最小限の設定
          [
            inputs.cells.core.nixosProfiles.vm
            inputs.cells.core.nixosProfiles.ssh-vm
          ]
        else
          # 実環境用の完全な設定
          [
            ./hardwareConfigurations/homeMachine.nix
            inputs.sops-nix.nixosModules.sops
            inputs.cells.core.nixosProfiles.sops
            inputs.cells.core.nixosProfiles.ssh-real
          ]
      );

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${homeMachineUsername} = {
        imports = [
          inputs.cells.core.homeProfiles.default
          inputs.cells.shinbunbun.homeProfiles.default

          inputs.cells.dev.homeProfiles.git
          inputs.cells.dev.homeProfiles.zsh
          inputs.cells.dev.homeProfiles.vim
          inputs.cells.dev.homeProfiles.manage_secrets
        ];
      };
    };
  };

  # ciMachine = {
  #   bee = {
  #     system = "x86_64-linux";
  #     pkgs = inputs.nixpkgs;
  #   };

  #   imports = [
  #     ./hardwareConfigurations/homeMachine.nix
  #     inputs.cells.core.ciNixosProfiles.ciMachine
  #   ];

  # };
}

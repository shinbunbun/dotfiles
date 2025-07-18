# cells/dev/homeProfiles.nix
{
  inputs,
  cell,
}:
{
  # 分割されたモジュール
  git = import ./homeProfiles/version-control.nix { inherit inputs cell; };
  zsh = import ./homeProfiles/shell-tools.nix { inherit inputs cell; };
  vim = import ./homeProfiles/editors.nix { inherit inputs cell; };
  google_cloud_sdk = import ./homeProfiles/cloud-tools.nix { inherit inputs cell; };
  manage_secrets = import ./homeProfiles/security-tools.nix { inherit inputs cell; };
  cocoapods = import ./homeProfiles/development-tools.nix { inherit inputs cell; };
  claude_code = import ./homeProfiles/ai-tools.nix { inherit inputs cell; };

  # エイリアス（互換性のため）
  versionControl = import ./homeProfiles/version-control.nix { inherit inputs cell; };
  shellTools = import ./homeProfiles/shell-tools.nix { inherit inputs cell; };
  editors = import ./homeProfiles/editors.nix { inherit inputs cell; };
  cloudTools = import ./homeProfiles/cloud-tools.nix { inherit inputs cell; };
  securityTools = import ./homeProfiles/security-tools.nix { inherit inputs cell; };
  developmentTools = import ./homeProfiles/development-tools.nix { inherit inputs cell; };
  aiTools = import ./homeProfiles/ai-tools.nix { inherit inputs cell; };

  /*
    graphql =
    { pkgs, ... }: {
      home.packages = with pkgs; [
        get-graphql-schema
      ];
    };
  */

  /*
    biome =
    { pkgs, ... }: {
      home.packages = with pkgs; [
        biome
      ];
    };
  */
}

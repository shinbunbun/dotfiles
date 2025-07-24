# cells/dev/homeProfiles.nix
{
  inputs,
  cell,
}:
{
  # モジュール（camelCase）
  versionControl = import ./homeProfiles/version-control.nix { inherit inputs cell; };
  shellTools = import ./homeProfiles/shell-tools.nix { inherit inputs cell; };
  editors = import ./homeProfiles/editors.nix { inherit inputs cell; };
  cloudTools = import ./homeProfiles/cloud-tools.nix { inherit inputs cell; };
  securityTools = import ./homeProfiles/security-tools.nix { inherit inputs cell; };
  developmentTools = import ./homeProfiles/development-tools.nix { inherit inputs cell; };
  aiTools = import ./homeProfiles/ai-tools.nix { inherit inputs cell; };

}

# cells/dev/homeProfiles/version-control.nix
{ inputs, cell }:
{ pkgs, ... }:
let
  configValues = import ../../core/config.nix;
in
{
  programs.git = {
    enable = true;

    userName = configValues.git.userName;
    userEmail = configValues.git.userEmail;

    extraConfig = {
      core.editor = configValues.git.coreEditor;
    };
  };
}

# cells/dev/homeProfiles/version-control.nix
{ inputs, cell }:
{ pkgs, ... }:
{
  programs.git = {
    enable = true;

    userName = "shinbunbun";
    userEmail = "34409044+shinbunbun@users.noreply.github.com";

    extraConfig = {
      core.editor = "code --wait";
    };
  };
}

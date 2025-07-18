# cells/dev/homeProfiles/editors.nix
{ inputs, cell }:
{ pkgs, ... }:
{
  # vim config
  programs.vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [ vim-airline ];
  };
}

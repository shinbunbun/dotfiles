# cells/dev/homeProfiles/editors.nix
/*
  エディタ設定モジュール

  このモジュールはテキストエディタの設定を提供します：
  - vim: vim-airlineプラグイン付き

  コード編集に必要な基本的なエディタ設定を含みます。
*/
{ inputs, cell }:
{ pkgs, ... }:
{
  # vim config
  programs.vim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [ vim-airline ];
  };
}

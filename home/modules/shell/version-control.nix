/*
  バージョン管理ツール設定モジュール

  このモジュールはGitの設定を提供します：
  - Gitユーザー情報の設定
  - GPG署名の設定
  - Gitエイリアスの定義
  - git-ignoreヘルパー
  - github-cliツール

  config.nixからユーザー情報や設定を読み込みます。
*/
{ pkgs, ... }:
let
  configValues = import ../../../shared/config.nix;
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

/*
  home プロファイル共通モジュール

  bunbun / shinbunbun 両プロファイルで共有する imports・パッケージ・基本設定を一元管理します。
  各プロファイルはこのモジュールを import し、username/homeDirectory とプラットフォーム固有の
  差分設定（フォントなど）のみを宣言してください。
*/
{ inputs, pkgs, ... }:

let
  cfg = import ../../shared/config.nix;
in
{
  imports = [
    # 開発ツール
    ../modules/development/ai-tools.nix
    ../modules/development/cloud-tools.nix
    ../modules/development/development-tools.nix
    ../modules/development/editors.nix

    # シェルツール
    ../modules/shell/shell-tools.nix
    ../modules/shell/version-control.nix
    ../modules/shell/tmux.nix

    # セキュリティツール
    ../modules/security/security-tools.nix
  ];

  # 基本設定
  home.stateVersion = cfg.system.homeStateVersion;
  xdg.enable = true;

  # 共通パッケージ
  home.packages = with pkgs; [
    # システムツール
    gh
    llvm

    # Nix開発ツール
    nil
    nixd
    nixfmt
  ];

  # Home Managerの有効化
  programs.home-manager.enable = true;
}

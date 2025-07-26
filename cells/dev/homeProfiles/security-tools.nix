# cells/dev/homeProfiles/security-tools.nix
/*
  セキュリティツール設定モジュール

  このモジュールはセキュリティ関連のツールを提供します：
  - age: ファイル暗号化ツール
  - sops: シークレット管理ツール

  これらのツールはシークレット管理や暗号化に使用されます。
*/
{ inputs, cell }:
{ pkgs, ... }:
{
  home.packages = [
    pkgs.age
    pkgs.sops
  ];
}

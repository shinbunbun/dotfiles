/*
  開発シェル設定

  Nix 設定の編集 (nixos-rebuild / darwin-rebuild / nix fmt) と SOPS 暗号化
  シークレットの取り扱いに必要な汎用ツールを提供する。シークレットの復号は
  行わない (鍵管理・編集は sops コマンドを対話的に使う)。

  注: 旧 Cloudflare/Authentik の Terraform (terraform/) は Terrakube セルフホスト
  (dotfiles-private#327 Phase 4) へ移行済みのため、cloudflare/authentik provider 用の
  TF_VAR_* と AWS(R2) の SOPS export、および terraform / terraform-ls /
  cf-terraforming は撤去した。IaC は homelab-iac リポジトリ + Terrakube
  (push→webhook→run) で管理する。
*/
{ pkgs, inputs, ... }:

pkgs.mkShell {
  name = "nix-dotfiles-dev";

  buildInputs =
    with pkgs;
    [
      # Nix開発ツール
      nixfmt-tree
      nil
      nixd

      # SOPS (鍵管理・シークレット編集)
      age
      sops
      ssh-to-age

      # 一般的な開発ツール
      git
      gh
      jq
      yq
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
      inputs.nix-darwin.packages.${pkgs.system}.default
    ];

  shellHook = ''
    echo "=== Nix Dotfiles Development Shell ==="
    echo "Available commands:"
    echo "  - nixos-rebuild switch --flake .#homeMachine"
    echo "  - darwin-rebuild switch --flake .#macbook"
    echo "  - nix fmt"
    echo "  - nix flake check"
    echo "  - nix build"
    echo ""
    echo "SOPS tools available: age, sops, ssh-to-age"
    echo "======================================="
  '';
}

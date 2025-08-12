/*
  開発シェル設定

  このファイルは開発環境を定義します。
  必要なツールやスクリプトを提供します。
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

      # SOPSツール
      age
      sops
      ssh-to-age

      # 一般的な開発ツール
      git
      gh
      jq
      yq

      # Darwin固有のツール
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

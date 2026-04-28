/*
  direnv Darwin checkPhase 回避オーバーレイ

  direnv のテストスイート (test/direnv-test.bash, test/direnv-test.zsh) には
  シェル間の interactive な動作を含むシナリオが多数あり、macos-latest
  GitHub-hosted runner で実行すると `Testing base` の `Reloading
  (should be no-op)` 周辺で確定論的に無限沈黙する。

  ローカルの Mac 実機では通る (deploy-rs で deploy 実績あり) ため、CI 環境
  特有の問題と考えられる。本番動作には影響しないテストフェーズなので、
  Darwin に限り doCheck = false を当てて checkPhase 自体をスキップする。

  Linux 側では問題が出ないため no-op。

  撤去条件:
    - direnv 側 (or nixpkgs 側) で macos GitHub-hosted runner 互換性が
      改善された時
    - GitHub-hosted macos-latest 環境が更新されてテストが通るようになった時
*/
final: prev:
let
  inherit (prev) lib stdenv;
in
lib.optionalAttrs stdenv.isDarwin {
  direnv = prev.direnv.overrideAttrs (_: {
    doCheck = false;
  });
}

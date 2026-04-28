/*
  terraform Darwin strip 回避オーバーレイ

  terraform 1.14.9 (nixpkgs 2026-04-21 バンプ) 以降、Darwin の fixupPhase で
  llvm-strip が Mach-O export trie のイテレーションで無限ループに陥り、CI が
  6 時間でタイムアウトする (LLVM Bug 32405 系列の既知バグ)。

  nixpkgs の terraform はすでに `ldflags = ["-s" "-w"]` 付きでビルドされて
  おり DWARF / シンボルは生成されないため、strip しても削るものがない。
  そこで Darwin に限り `dontStrip = true` を当て、fixupPhase の strip 呼び出し
  自体をスキップする。バイナリサイズは変化しない。

  Linux 側では GNU strip が使われ Mach-O export trie 処理を持たないため、
  本オーバーレイは no-op。

  撤去条件:
    - nixpkgs の terraform default.nix に Darwin 向け dontStrip が入った時
    - LLVM 側で Mach-O export trie のループが修正された時
    - terraform 側で当該パターンを踏まないバージョンが出た時
*/
final: prev:
let
  inherit (prev) lib stdenv;
in
lib.optionalAttrs stdenv.isDarwin {
  terraform = prev.terraform.overrideAttrs (_: {
    dontStrip = true;
  });
}

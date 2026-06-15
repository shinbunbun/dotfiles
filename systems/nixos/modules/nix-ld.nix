# nix-ld（動的リンカー）共有モジュール
#
# 機能:
#   - programs.nix-ld を有効化し、NixOS 非対応のビルド済みバイナリ（FHS 前提で
#     リンクされた ELF）を実行可能にする。
#   - nix-ld が解決対象とする共有ライブラリを programs.nix-ld.libraries で明示する。
#     enable だけではライブラリ集合が空に近く、ネイティブ拡張を持つツールが
#     `libstdc++.so.6` 等を解決できず ImportError でクラッシュする。
#
# 提供する設定:
#   - programs.nix-ld.enable = true
#   - programs.nix-ld.libraries: stdenv.cc.cc.lib（libstdc++.so.6 / libgcc_s.so.1）と zlib
#
# 使用方法:
#   nix-ld 経由で foreign binary を動かすホスト（例: homeMachine — uvx 由来の
#   standalone Python で mcp-server-motherduck = DuckDB ネイティブ拡張を実行する）の
#   configuration から imports に追加する。必要な共有ライブラリが増えたら
#   programs.nix-ld.libraries に追記する。
{
  pkgs,
  ...
}:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
  ];
}

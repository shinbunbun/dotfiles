/*
  ローカルLLM推論ツール設定モジュール

  Apple Silicon Mac向けのMLXベースLLM推論環境を提供します：
  - mlx-lm: Apple MLXフレームワークによるLLM推論ツール
  - 対応コマンド: mlx_lm.generate, mlx_lm.chat, mlx_lm.server, mlx_lm.convert

  使用方法:
    python -m mlx_lm.generate --model mlx-community/Qwen3.5-4B-MLX-4bit --prompt "Hello"
    python -m mlx_lm.chat --model mlx-community/Qwen3.5-4B-MLX-4bit
    python -m mlx_lm.server --model mlx-community/Qwen3.5-4B-MLX-4bit --port 8080
*/
{ pkgs, lib, ... }:
let
  mlxPython = pkgs.python313.withPackages (ps: [
    ps.mlx-lm
  ]);
in
{
  home.packages = lib.optionals pkgs.stdenv.isDarwin [
    mlxPython
  ];
}

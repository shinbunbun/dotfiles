/*
  ローカルLLM推論ツール設定モジュール

  Apple Silicon Mac向けのMLXベースLLM推論環境を提供します：
  - mlx-lm: Apple MLXフレームワークによるLLM推論ツール
  - launchdエージェントによるOpenAI互換APIサーバーの常時起動
  - 対応コマンド: mlx_lm.generate, mlx_lm.chat, mlx_lm.server, mlx_lm.convert

  使用方法:
    python -m mlx_lm.generate --model mlx-community/Qwen3.5-4B-MLX-4bit --prompt "Hello"
    python -m mlx_lm.chat --model mlx-community/Qwen3.5-4B-MLX-4bit
    # サーバーはlaunchdで自動起動（ポート8080）
*/
{ pkgs, lib, ... }:
let
  cfg = import ../../../shared/config.nix;

  mlxPython = pkgs.python313.withPackages (ps: [
    ps.mlx-lm
  ]);
in
{
  home.packages = lib.optionals pkgs.stdenv.isDarwin [
    mlxPython
  ];

  launchd.agents.mlx-lm-server = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "com.mlx-lm.server";
      ProgramArguments = [
        "${mlxPython}/bin/python"
        "-m"
        "mlx_lm.server"
        "--model"
        cfg.mlxLm.model
        "--port"
        (builtins.toString cfg.mlxLm.port)
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/mlx-lm-server.log";
      StandardErrorPath = "/tmp/mlx-lm-server.error.log";
    };
  };
}

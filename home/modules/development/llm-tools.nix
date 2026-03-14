/*
  ローカルLLM推論ツール設定モジュール

  Apple Silicon Mac向けのMLXベースLLM推論環境を提供します：
  - mlx-lm: Apple MLXフレームワークによるLLM推論ツール
  - launchdエージェントによるOpenAI互換APIサーバーの常時起動
  - 対応コマンド: mlx_lm.generate, mlx_lm.chat, mlx_lm.server, mlx_lm.convert

  メモリチューニング（Mac mini M1 8GB向け）:
  - KVキャッシュ512MB制限でメモリ使用量を抑制
  - 同時キャッシュ数1でメモリ効率を最大化
  - 思考モード無効化（2Bモデルでは精度が不安定なため）

  使用方法:
    python -m mlx_lm generate --model mlx-community/Qwen3.5-2B-OptiQ-4bit --prompt "Hello"
    python -m mlx_lm chat --model mlx-community/Qwen3.5-2B-OptiQ-4bit
    # サーバーはlaunchdで自動起動（ポート8081）
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
        "mlx_lm"
        "server"
        "--model"
        cfg.mlxLm.model
        "--port"
        (builtins.toString cfg.mlxLm.port)
        "--prompt-cache-bytes"
        "536870912" # KVキャッシュ512MB制限
        "--prompt-cache-size"
        "1" # 同時キャッシュ数1
        "--chat-template-args"
        "{\"enable_thinking\":false}" # 思考モード無効化（2Bモデルでは不安定）
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/mlx-lm-server.log";
      StandardErrorPath = "/tmp/mlx-lm-server.error.log";
    };
  };
}

/*
  llama.cpp ベースの OpenAI 互換 LLM 推論サーバ

  機能:
  - llama-server を systemd で常駐
  - GGUF モデルを CPU で推論 (MoE モデルは --n-cpu-moe で expert FFN を CPU 強制)
  - OpenAI 互換 API エンドポイント (/v1/chat/completions など)
  - DynamicUser + StateDirectory + 各種 Protect* で隔離
  - --mlock で常駐ロック、CPUAffinity で P-core 固定可能
  - 任意で別パッケージ (例: pkgs.ik-llama-cpp) に差し替え可能

  設計方針:
  - shared/sections/services.nix の llamaCpp セクションをデフォルト値の供給源とする
  - ホストごとに modelPath を指定し enable する (nixos-desktop で Qwen3.6-35B-A3B 等)
  - macmini の mlx-lm.server (port 8081) と並存することを前提にデフォルトポートは 8082

  使用方法:
    services.llamaCpp = {
      enable = true;
      modelPath = "/var/lib/llama-cpp/models/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
      cpuAffinity = "0-15";  # P-core 固定 (i7-13700K の場合)
      openFirewall = true;
    };
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  sharedCfg = import ../../../../shared/config.nix;
  cfg = config.services.llamaCpp;

  # systemd unit に渡す引数を組み立てる。
  # nCpuMoe = 0 の場合は --n-cpu-moe を付けない (機能無効化)。
  baseArgs = [
    "--model"
    cfg.modelPath
    "--alias"
    cfg.modelAlias
    "--host"
    cfg.host
    "--port"
    (toString cfg.port)
    "--threads"
    (toString cfg.threads)
    "--threads-batch"
    (toString cfg.threadsBatch)
    "--ctx-size"
    (toString cfg.contextSize)
    "--parallel"
    (toString cfg.parallelSlots)
  ]
  ++ lib.optionals (cfg.nCpuMoe > 0) [
    "--n-cpu-moe"
    (toString cfg.nCpuMoe)
  ]
  ++ lib.optional (!cfg.useMmap) "--no-mmap"
  ++ lib.optional cfg.mlock "--mlock"
  ++ lib.optional cfg.useJinja "--jinja"
  ++ cfg.extraArgs;

  argsString = lib.escapeShellArgs baseArgs;
in
{
  options.services.llamaCpp = {
    enable = lib.mkEnableOption "llama.cpp ベースの OpenAI 互換 LLM 推論サーバ";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp;
      defaultText = lib.literalExpression "pkgs.llama-cpp";
      description = ''
        llama-server バイナリを提供するパッケージ。
        ik_llama.cpp を使う場合は overlay で pkgs.ik-llama-cpp 等に差し替えて指定する。
      '';
    };

    modelPath = lib.mkOption {
      type = lib.types.str;
      description = "GGUF モデルファイルの絶対パス。事前に配置されている必要がある。";
      example = "/var/lib/llama-cpp/models/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    };

    modelAlias = lib.mkOption {
      type = lib.types.str;
      default = sharedCfg.llamaCpp.modelAlias;
      description = "OpenAI API の /v1/models で表示するモデル識別子。";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = sharedCfg.llamaCpp.host;
      description = "リッスンアドレス (LAN 公開時は 0.0.0.0)。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = sharedCfg.llamaCpp.port;
      description = "HTTP API ポート。";
    };

    threads = lib.mkOption {
      type = lib.types.ints.positive;
      default = sharedCfg.llamaCpp.threads;
      description = "decode 時のスレッド数 (推奨: P-core の物理コア数)。";
    };

    threadsBatch = lib.mkOption {
      type = lib.types.ints.positive;
      default = sharedCfg.llamaCpp.threadsBatch;
      description = "prefill (バッチ評価) 時のスレッド数 (推奨: HT 含む P-core 全論理コア)。";
    };

    contextSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = sharedCfg.llamaCpp.contextSize;
      description = "コンテキストウィンドウのサイズ (トークン)。";
    };

    parallelSlots = lib.mkOption {
      type = lib.types.ints.positive;
      default = sharedCfg.llamaCpp.parallelSlots;
      description = "同時に処理できるリクエスト数 (各 slot はコンテキストを分割して保持)。";
    };

    nCpuMoe = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = sharedCfg.llamaCpp.nCpuMoe;
      description = ''
        --n-cpu-moe N: 先頭 N 層の MoE expert FFN を CPU に固定する。
        0 で機能無効化。MoE モデル (Qwen3 A3B 等) を CPU 推論する際に必須。
      '';
    };

    cpuAffinity = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "0-15";
      description = ''
        systemd CPUAffinity の値。空文字で affinity 指定なし。
        i7-13700K の場合 "0-15" で P-core (HT 含む) に固定し、E-core を他サービスに明け渡す。
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "llama-server に追加で渡す引数。エンジン差 (ik_llama.cpp の独自フラグ等) を吸収する用途。";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "ファイアウォールで port を開放する (LAN 内の他ホストから利用する場合に true)。";
    };

    memoryHigh = lib.mkOption {
      type = lib.types.str;
      default = "28G";
      description = "systemd MemoryHigh (ソフトリミット、超えると圧迫されるが OOM はしない)。";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "32G";
      description = "systemd MemoryMax (ハードリミット、超えると OOM kill)。";
    };

    nice = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "プロセスの nice 値 (大きいほど優先度低)。他サービスを優先したい場合は 5 程度。";
    };

    cpuWeight = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50;
      description = "systemd CPUWeight (デフォ 100、低くすると競合時に他サービスへ CPU を譲る)。";
    };

    mlock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "--mlock を有効化 (モデル全体を物理メモリに常駐ロック)。";
    };

    useMmap = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "mmap を使う (true) / 使わない (false)。--mlock と併用するなら false 推奨。";
    };

    useJinja = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "--jinja を有効化 (モデル組込みの chat template を使用)。";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/llama-cpp 0755 root root -"
      "d /var/lib/llama-cpp/models 0755 root root -"
    ];

    systemd.services.llama-cpp = {
      description = "llama.cpp OpenAI-compatible inference server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # モデルファイルが存在しない状態での起動を抑制
      unitConfig = {
        ConditionPathExists = cfg.modelPath;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/llama-server ${argsString}";

        DynamicUser = true;
        StateDirectory = "llama-cpp";

        # --mlock 用に CAP_IPC_LOCK を許可 (mlock 無効時は空リスト)
        AmbientCapabilities = lib.optional cfg.mlock "CAP_IPC_LOCK";
        CapabilityBoundingSet = lib.optional cfg.mlock "CAP_IPC_LOCK";

        # メモリ・CPU・IO の上限と優先度
        MemoryHigh = cfg.memoryHigh;
        MemoryMax = cfg.memoryMax;
        CPUWeight = cfg.cpuWeight;
        IOWeight = 50;
        Nice = cfg.nice;

        # Hardening (モデルファイル読み取り + StateDirectory 書き込みのみ許可)
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        ReadOnlyPaths = [ cfg.modelPath ];

        Restart = "on-failure";
        RestartSec = 30;
      }
      // lib.optionalAttrs cfg.mlock {
        LimitMEMLOCK = "infinity";
      }
      // lib.optionalAttrs (cfg.cpuAffinity != "") {
        CPUAffinity = cfg.cpuAffinity;
      };
    };

    networking.firewall.allowedTCPPorts = lib.optional cfg.openFirewall cfg.port;
  };
}

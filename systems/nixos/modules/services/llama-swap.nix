/*
  llama-swap ベースの OpenAI 互換 model-swapping 推論プロキシ

  機能:
  - llama-swap を systemd で常駐し、単一 endpoint(:port) から OpenAI 互換 API を公開
  - リクエストの model 名で複数の GGUF モデルを on-demand 起動/切替 (llama-server を子プロセスとして spawn)
  - 各モデルは ttl で idle unload
  - 任意で NVIDIA GPU デバイスアクセスを許可 (DynamicUser + PrivateDevices=false + DeviceAllow)
  - DynamicUser + StateDirectory + 各種 Protect* で隔離

  設計方針:
  - 推論エンジン (llama-server) は serverPackage で差し替え可能 (CPU / CUDA ビルド等)
  - モデル定義はホスト側が services.llamaSwap.models で与える (エンジン非依存の汎用モジュール)
  - 従来の単一モデル常駐 (services.llamaCpp) に対し、本モジュールは複数モデルの動的切替を担う

  使用方法:
    services.llamaSwap = {
      enable = true;
      serverPackage = inputs.self.packages.x86_64-linux.llama-cpp-cuda;  # llama-server 提供元
      enableNvidiaGpu = true;
      openFirewall = true;
      requiredPaths = [ "/var/lib/llama-cpp/models/foo.gguf" ];  # 揃うまで起動抑制
      models."foo" = {
        args = [ "--model" "/var/lib/llama-cpp/models/foo.gguf" "--n-gpu-layers" "999" ];
        aliases = [ "foo-alias" ];
        ttl = 1800;
      };
    };

  注意:
  - モデルファイルは Nix derivation 化しない前提 (サイズのため手動配置)。requiredPaths に列挙した
    ファイルが揃うまで ConditionPathExists で起動をスキップする。
  - modelsDir (既定 /var/lib/llama-cpp/models) は tmpfiles で作成する。StateDirectory の
    private 移送 gotcha を避けるため親 (/var/lib/llama-cpp) は宣言しない。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.llamaSwap;
  yamlFormat = pkgs.formats.yaml { };

  serverBin = "${cfg.serverPackage}/bin/llama-server";

  # llama-swap の設定を生成する。cmd の "''${PORT}" は llama-swap が各モデルへ割り当てる内部
  # ポートに実行時展開するプレースホルダ (Nix ではリテラル ${PORT} として埋め込む)。cmd は
  # 空白区切り単一行だが llama-swap がシェル的にトークン化する。JSON 等クォートが必要な引数は
  # ホスト側が args 要素として単一引用符付きで渡すこと (例: "'{\"enable_thinking\":false}'")。
  #
  # m.port を設定した場合は ''${PORT} の自動割当ではなく固定ポートで llama-server を起動し、
  # llama-swap の proxy をそのポートへ向ける。llama-swap の /metrics は host/GPU 統計のみで
  # 推論 tps (llamacpp:*) を出さないため、llama-server の /metrics を外部 Prometheus から
  # 直接 scrape したいときに使う (別途 args に "--host" "0.0.0.0" と openFirewall が必要)。
  modelToConfig =
    _name: m:
    let
      portArg = if m.port != null then toString m.port else "\${PORT}";
    in
    {
      cmd = lib.concatStringsSep " " (
        [ serverBin ]
        ++ m.args
        ++ [
          "--port"
          portArg
        ]
      );
      ttl = m.ttl;
    }
    // lib.optionalAttrs (m.aliases != [ ]) { inherit (m) aliases; }
    // lib.optionalAttrs (m.port != null) {
      proxy = "http://127.0.0.1:${toString m.port}";
    };

  swapConfig = yamlFormat.generate "llama-swap.yaml" {
    inherit (cfg) healthCheckTimeout logLevel;
    models = lib.mapAttrs modelToConfig cfg.models;
  };

  nvidiaDevices = [
    "/dev/nvidia0 rwm"
    "/dev/nvidiactl rwm"
    "/dev/nvidia-uvm rwm"
    "/dev/nvidia-uvm-tools rwm"
    "/dev/nvidia-modeset rwm"
  ];
in
{
  options.services.llamaSwap = {
    enable = lib.mkEnableOption "llama-swap ベースの OpenAI 互換 model-swapping 推論プロキシ";

    swapPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-swap;
      defaultText = lib.literalExpression "pkgs.llama-swap";
      description = "llama-swap バイナリを提供するパッケージ。";
    };

    serverPackage = lib.mkOption {
      type = lib.types.package;
      description = ''
        llama-server バイナリを提供するパッケージ。CPU ビルド (pkgs.llama-cpp) や
        GPU/CUDA ビルドをホスト側で指定する。
      '';
      example = lib.literalExpression "inputs.self.packages.x86_64-linux.llama-cpp-cuda";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "リッスンアドレス (LAN 公開時は 0.0.0.0)。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "HTTP API ポート。";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "ファイアウォールで port を開放する。";
    };

    healthCheckTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "各モデルの起動 health check タイムアウト秒 (大きめの GPU モデルロードを想定)。";
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "llama-swap のログレベル。";
    };

    enableNvidiaGpu = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        NVIDIA GPU デバイスへのアクセスを許可する。true で PrivateDevices=false +
        /dev/nvidia* への DeviceAllow を付与する (false のままだと GPU を使えない)。
      '';
    };

    modelsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/llama-cpp/models";
      description = "GGUF モデル配置ディレクトリ (tmpfiles で作成)。";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.str;
      default = "llama-cpp";
      description = "systemd StateDirectory 名 (/var/lib/<name>)。";
    };

    requiredPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        ConditionPathExists に渡すファイル群。ここに列挙したファイルが全て揃うまで
        サービス起動をスキップする (モデル未配置でのデプロイを起動失敗にしない)。
      '';
    };

    models = lib.mkOption {
      description = "llama-swap が切り替えるモデル定義 (キー = model 名)。";
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = ''
                llama-server に渡す引数リスト (--model <path> を含む)。--port は
                モジュールが自動付与するため含めない。クォートが必要な値 (JSON 等) は
                単一引用符で囲んだ文字列要素として渡す。
              '';
            };
            aliases = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "この model 名に別名でルーティングするための alias。";
            };
            ttl = lib.mkOption {
              type = lib.types.ints.positive;
              default = 1800;
              description = "idle unload までの秒数。";
            };
            port = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = ''
                固定 upstream ポート。設定すると llama-server を --port <port> で起動し、
                llama-swap は proxy: http://127.0.0.1:<port> でこのモデルへ接続する。
                llama-server の /metrics を外部 Prometheus から直接 scrape する用途
                (llama-swap 自身の /metrics は host/GPU 統計のみで推論 tps を出さないため)。
                null なら llama-swap が startPort から自動割当する (''${PORT})。
                外部 scrape するにはモデルの args に "--host" "0.0.0.0" を含め、
                openFirewall でこのポートも開放すること (openFirewall=true なら自動で開く)。
              '';
            };
          };
        }
      );
    };

    memoryHigh = lib.mkOption {
      type = lib.types.str;
      default = "20G";
      description = "systemd MemoryHigh (ソフトリミット)。";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "28G";
      description = "systemd MemoryMax (ハードリミット)。";
    };

    nice = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "プロセスの nice 値。";
    };

    cpuWeight = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50;
      description = "systemd CPUWeight (競合時に他サービスへ CPU を譲る)。";
    };
  };

  config = lib.mkIf cfg.enable {
    # StateDirectory の private 移送 gotcha を避けるため親 (modelsDir の親) は宣言せず
    # models ディレクトリ 1 行だけにする (services.llamaCpp モジュールと同じ理由)。
    systemd.tmpfiles.rules = [
      "d ${cfg.modelsDir} 0755 root root -"
    ];

    systemd.services.llama-swap = {
      description = "llama-swap OpenAI-compatible model-swapping proxy";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      unitConfig = lib.mkIf (cfg.requiredPaths != [ ]) {
        ConditionPathExists = cfg.requiredPaths;
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.swapPackage}/bin/llama-swap -config ${swapConfig} -listen ${cfg.host}:${toString cfg.port} -watch-config";

        DynamicUser = true;
        StateDirectory = cfg.stateDirectory;

        CPUWeight = cfg.cpuWeight;
        IOWeight = 50;
        Nice = cfg.nice;
        MemoryHigh = cfg.memoryHigh;
        MemoryMax = cfg.memoryMax;

        # Hardening (モデルファイル読み取り + StateDirectory 書き込みのみ許可)
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        ReadOnlyPaths = cfg.requiredPaths;

        Restart = "on-failure";
        RestartSec = 30;

        # GPU アクセス: PrivateDevices=true だと /dev/nvidia* が見えず GPU を使えない。
        PrivateDevices = !cfg.enableNvidiaGpu;
      }
      // lib.optionalAttrs cfg.enableNvidiaGpu {
        DeviceAllow = nvidiaDevices;
      };
    };

    # openFirewall では llama-swap の proxy port に加え、固定 upstream port
    # (models.<name>.port) も開放する (llama-server /metrics を外部 scrape するため)。
    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall (
      [ cfg.port ] ++ lib.filter (p: p != null) (lib.mapAttrsToList (_: m: m.port) cfg.models)
    );
  };
}

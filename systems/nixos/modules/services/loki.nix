/*
  Lokiログ集約システム設定モジュール

  このモジュールは以下の機能を提供します：
  - Loki: ログ集約・検索エンジン
  - データ保持期間: 30日（config.nixで設定可能）
  - S3互換ストレージへの対応（将来の拡張用）
  - Grafanaとの統合

  使用方法:
  - homeMachineにインポートして使用
  - Promtailまたは Vectorから ログを受信
  - Grafanaデータソースとして登録
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # config.nixから設定を読み込み
  cfg = import ../../../../shared/config.nix;
in
{
  # Loki設定
  services.loki = {
    enable = true;

    configuration = {
      # 認証を無効化（内部ネットワークのみ）
      auth_enabled = false;

      # サーバー設定
      server = {
        http_listen_port = cfg.monitoring.loki.port;
        grpc_listen_port = 9095;
        log_level = "info";
      };

      # データ取り込み設定
      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        # チャンクのアイドル期間
        chunk_idle_period = "5m";
        # チャンクの最大保持期間
        chunk_retain_period = "30s";
        # チャンクのターゲットサイズ
        chunk_target_size = cfg.monitoring.loki.chunkTargetSize;
        # WAL（Write-Ahead Log）の有効化
        wal = {
          enabled = true;
          dir = "${cfg.monitoring.loki.dataDir}/wal";
        };
      };

      # スキーマ設定
      schema_config = {
        configs = [
          {
            from = "2020-01-01";
            store = "boltdb-shipper";
            object_store = "filesystem";
            schema = "v11";
            index = {
              prefix = "loki_index_";
              period = "24h";
            };
          }
        ];
      };

      # ストレージ設定
      storage_config = {
        boltdb_shipper = {
          active_index_directory = "${cfg.monitoring.loki.dataDir}/boltdb-shipper-active";
          cache_location = "${cfg.monitoring.loki.dataDir}/boltdb-shipper-cache";
        };
        filesystem = {
          directory = "${cfg.monitoring.loki.dataDir}/chunks";
        };
      };

      # 制限設定
      limits_config = {
        # 取り込みレート制限（バイト/秒）- config.nixの設定値を使用（デフォルト10MB/s）
        ingestion_rate_mb = cfg.monitoring.loki.ingestionRateLimit / 1048576;
        # 取り込みバーストサイズ（バイト）- config.nixの設定値を使用（デフォルト20MB）
        ingestion_burst_size_mb = cfg.monitoring.loki.ingestionBurstSize / 1048576;
        # クエリの並列実行数
        max_query_parallelism = 32;
        # ストリームごとのレート制限（10MB/sに設定 - 十分な余裕を持たせる）
        per_stream_rate_limit = "10MB";
        # ストリームごとのバーストサイズ（20MBに設定 - 初期ログの大量送信に対応）
        per_stream_rate_limit_burst = "20MB";
        # ラベルの最大数
        max_label_names_per_series = 30;
        # ラベル値の最大長
        max_label_value_length = 2048;
        # ラベル名の最大長
        max_label_name_length = 1024;
        # クエリで返される最大エントリ数
        max_entries_limit_per_query = 100000;
        # エラーを強制しない
        reject_old_samples = true;
        reject_old_samples_max_age = "168h"; # 7日
        # 構造化メタデータを無効化（v11スキーマのため）
        allow_structured_metadata = false;
      };

      # テーブルマネージャー設定
      table_manager = {
        retention_deletes_enabled = true;
        retention_period = "${toString cfg.monitoring.loki.retentionDays}d";
      };

      # コンパクター設定（データ圧縮と古いデータの削除）
      compactor = {
        working_directory = "${cfg.monitoring.loki.dataDir}/compactor";
        compaction_interval = "10m";
        retention_enabled = true;
        retention_delete_delay = "2h";
        retention_delete_worker_count = 150;
        delete_request_store = "filesystem";
      };

      # ルーラー設定（アラートルール評価）
      ruler = {
        storage = {
          type = "local";
          local = {
            directory = "${cfg.monitoring.loki.dataDir}/rules";
          };
        };
        rule_path = "${cfg.monitoring.loki.dataDir}/rules-temp";
        alertmanager_url = "http://localhost:${toString cfg.monitoring.alertmanager.port}";
        ring = {
          kvstore = {
            store = "inmemory";
          };
        };
        enable_api = true;
        enable_alertmanager_v2 = true;
      };

      # クエリ範囲設定
      query_range = {
        # 結果のキャッシュを有効化
        results_cache = {
          cache = {
            embedded_cache = {
              enabled = true;
              max_size_mb = 100;
            };
          };
        };
      };

      # フロントエンド設定
      frontend = {
        compress_responses = true;
      };
    };
  };

  # systemdサービスの設定
  systemd.services.loki = {
    serviceConfig = {
      # メモリ制限
      MemoryMax = "2G";
      MemoryHigh = "1500M";
      # CPU制限
      CPUQuota = "200%";
      # 再起動ポリシー（デフォルトを上書き）
      Restart = lib.mkForce "on-failure";
      RestartSec = "10s";
      # データディレクトリの作成
      StateDirectory = "loki";
      StateDirectoryMode = "0750";
    };
    # ルールファイルのセットアップ
    preStart = ''
      # ディレクトリが既に存在し、lokiユーザーが所有者でない場合は修正
      if [ -d ${cfg.monitoring.loki.dataDir}/rules ]; then
        chown -R loki:loki ${cfg.monitoring.loki.dataDir}/rules || true
      fi
      mkdir -p ${cfg.monitoring.loki.dataDir}/rules/fake
      cp -f ${./loki-rules.yaml} ${cfg.monitoring.loki.dataDir}/rules/fake/rules.yaml
      chown -R loki:loki ${cfg.monitoring.loki.dataDir}/rules
    '';
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [
    cfg.monitoring.loki.port # Loki HTTP API
    9095 # Loki gRPC（内部通信用）
  ];

  # システムパッケージにLokiツールを追加
  environment.systemPackages = with pkgs; [
    loki
    grafana-loki # Lokiコマンドラインクライアント
  ];
}

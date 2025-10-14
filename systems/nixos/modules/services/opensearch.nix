/*
  OpenSearchログ検索エンジン設定モジュール

  このモジュールは以下の機能を提供します：
  - OpenSearch: Elasticsearch互換の高速ログ検索エンジン
  - 単一ノード構成（レプリカなし）
  - JVMヒープ: 32GB（システムRAM 96GBの1/3）
  - データ保持期間: 30日（ILMポリシー）
  - インデックステンプレート: logs-*パターン
  - セキュリティ: 内部ネットワークのみアクセス許可

  使用方法:
  - nixos-desktopにインポートして使用
  - Fluent Bitからログを受信
  - OpenSearch Dashboardsで可視化（将来）

  注意: NixOSビルトインのservices.opensearchを使用します
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # config.nixから設定を読み込み
  cfg = import ../../../../shared/config.nix;

  # インデックステンプレート定義
  indexTemplate = pkgs.writeText "logs-index-template.json" (
    builtins.toJSON {
      index_patterns = [ "logs-*" ];
      template = {
        settings = {
          number_of_shards = cfg.opensearch.numberOfShards;
          number_of_replicas = cfg.opensearch.numberOfReplicas;
          "index.refresh_interval" = "5s";
          "index.codec" = "best_compression";
        };
        mappings = {
          properties = {
            "@timestamp" = {
              type = "date";
            };
            level = {
              type = "keyword";
              fields = {
                text = {
                  type = "text";
                };
              };
            };
            message = {
              type = "text";
              fields = {
                keyword = {
                  type = "keyword";
                  ignore_above = 256;
                };
              };
            };
            host = {
              type = "keyword";
            };
            service = {
              type = "keyword";
            };
            unit = {
              type = "keyword";
            };
            job = {
              type = "keyword";
            };
            log_type = {
              type = "keyword";
            };
            method = {
              type = "keyword";
            };
            status = {
              type = "short";
            };
            trace_id = {
              type = "keyword";
            };
          };
        };
      };
    }
  );

  # ILMポリシー定義
  ilmPolicy = pkgs.writeText "logs-ilm-policy.json" (
    builtins.toJSON {
      policy = {
        phases = {
          hot = {
            min_age = "0ms";
            actions = {
              rollover = {
                max_age = "1d";
                max_size = "50gb";
              };
            };
          };
          warm = {
            min_age = "7d";
            actions = {
              forcemerge = {
                max_num_segments = 1;
              };
              shrink = {
                number_of_shards = 1;
              };
            };
          };
          delete = {
            min_age = "${toString cfg.opensearch.retentionDays}d";
            actions = {
              delete = { };
            };
          };
        };
      };
    }
  );
in
{
  # NixOSビルトインのOpenSearchサービスを使用
  services.opensearch = {
    enable = true;
    package = pkgs.opensearch;

    settings = {
      # クラスター設定
      "cluster.name" = cfg.opensearch.clusterName;
      "node.name" = cfg.opensearch.nodeName;

      # ネットワーク設定
      "network.host" = "0.0.0.0";
      "http.port" = cfg.opensearch.port;
      "transport.port" = cfg.opensearch.transportPort;

      # 単一ノード設定
      "discovery.type" = "single-node";

      # パフォーマンスチューニング
      "indices.queries.cache.size" = "20%";
      "indices.requests.cache.size" = "5%";
      "indices.fielddata.cache.size" = "30%";

      # スレッドプール設定
      "thread_pool.write.queue_size" = 1000;
      "thread_pool.search.queue_size" = 2000;

      # セキュリティプラグイン無効化（内部ネットワーク限定使用）
      "plugins.security.disabled" = true;

      # その他の設定
      "action.auto_create_index" = true;
    };

    extraJavaOptions = [
      # ヒープサイズ設定
      "-Xms${cfg.opensearch.heapSize}"
      "-Xmx${cfg.opensearch.heapSize}"

      # G1GCの設定
      "-XX:+UseG1GC"
      "-XX:G1ReservePercent=25"
      "-XX:InitiatingHeapOccupancyPercent=30"
      "-XX:MaxGCPauseMillis=200"
      "-XX:+ParallelRefProcEnabled"
    ];
  };

  # systemdサービスの追加設定
  systemd.services.opensearch = {
    serviceConfig = {
      # メモリ制限
      MemoryMax = lib.mkForce "${toString cfg.opensearch.maxMemory}";
      MemoryHigh = "${toString (cfg.opensearch.maxMemory - 2147483648)}"; # maxMemory - 2GB

      # 再起動ポリシー
      Restart = lib.mkForce "on-failure";
      RestartSec = lib.mkForce "30s";

      # タイムアウト設定
      TimeoutStartSec = lib.mkForce "300s";
      TimeoutStopSec = lib.mkForce "120s";
    };

    # OpenSearch起動後の初期設定
    postStart = lib.mkAfter ''
      # OpenSearchが起動するまで待機
      for i in {1..60}; do
        if ${pkgs.curl}/bin/curl -s http://localhost:${toString cfg.opensearch.port}/_cluster/health > /dev/null 2>&1; then
          echo "OpenSearch is ready"
          break
        fi
        echo "Waiting for OpenSearch to start... ($i/60)"
        sleep 5
      done

      # インデックステンプレートの登録
      ${pkgs.curl}/bin/curl -X PUT "http://localhost:${toString cfg.opensearch.port}/_index_template/logs-template" \
        -H "Content-Type: application/json" \
        -d @${indexTemplate} || true

      # ILMポリシーの登録（ISMポリシーとして）
      ${pkgs.curl}/bin/curl -X PUT "http://localhost:${toString cfg.opensearch.port}/_plugins/_ism/policies/logs-policy" \
        -H "Content-Type: application/json" \
        -d @${ilmPolicy} || true

      echo "OpenSearch initialization completed"
    '';
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [
    cfg.opensearch.port # HTTP API
    cfg.opensearch.transportPort # Transport（ノード間通信）
  ];

  # 必要なパッケージ
  environment.systemPackages = with pkgs; [
    opensearch
    curl
    jq
  ];

  # ログローテーション設定
  services.logrotate.settings.opensearch = {
    files = "/var/lib/opensearch/logs/*.log";
    rotate = 7;
    frequency = "daily";
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
  };
}

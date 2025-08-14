/*
  ClickHouseログ分析エンジン設定モジュール

  このモジュールは以下の機能を提供します：
  - ClickHouse: 高速カラムナストア分析DB
  - ログデータの長期保存（180日）
  - 集計用マテリアライズドビュー
  - 異常検知結果の保存
  - Grafanaからのクエリ対応

  使用方法:
  - nixos-desktopにインポートして使用
  - Lokiからのデータを定期的に取り込み
  - 高負荷な分析処理を実行
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
in
{
  # ClickHouse設定
  services.clickhouse = {
    enable = true;
    package = pkgs.clickhouse;
  };

  # ClickHouseの設定をsystemdの環境変数で管理
  systemd.services.clickhouse.environment = {
    CLICKHOUSE_HTTP_PORT = toString cfg.monitoring.clickhouse.port;
    CLICKHOUSE_TCP_PORT = toString cfg.monitoring.clickhouse.nativePort;
    CLICKHOUSE_INTERSERVER_HTTP_PORT = toString cfg.monitoring.clickhouse.interserverPort;
    CLICKHOUSE_MAX_MEMORY_USAGE = toString cfg.monitoring.clickhouse.maxMemoryUsage;
    CLICKHOUSE_PATH = cfg.monitoring.clickhouse.dataDir;
    CLICKHOUSE_TMP_PATH = "${cfg.monitoring.clickhouse.dataDir}/tmp";
    CLICKHOUSE_USER_FILES_PATH = "${cfg.monitoring.clickhouse.dataDir}/user_files";
    CLICKHOUSE_LISTEN_HOST = "0.0.0.0";
  };

  # 起動時にテーブルとマテリアライズドビューを作成
  systemd.services.clickhouse-init = {
    description = "Initialize ClickHouse tables and views";
    after = [ "clickhouse.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "clickhouse";
      Group = "clickhouse";
    };

    script = ''
      # ClickHouseが起動するまで待機
      until ${pkgs.clickhouse}/bin/clickhouse-client --query "SELECT 1" > /dev/null 2>&1; do
        echo "Waiting for ClickHouse to start..."
        sleep 2
      done

      # データベース作成
      ${pkgs.clickhouse}/bin/clickhouse-client --query "
        CREATE DATABASE IF NOT EXISTS logs
      "

      # メインのログテーブル作成
      ${pkgs.clickhouse}/bin/clickhouse-client --query "
        CREATE TABLE IF NOT EXISTS logs.${cfg.monitoring.clickhouse.logsTableName} (
          ts DateTime64(3),
          host String,
          service String,
          unit String,
          level String,
          path String,
          status UInt16,
          latency_ms Float32,
          trace_id String,
          message String,
          attrs String,  -- JSON string
          
          -- 追加のインデックス用カラム
          date Date DEFAULT toDate(ts),
          hour DateTime DEFAULT toStartOfHour(ts)
        )
        ENGINE = MergeTree()
        PARTITION BY toYYYYMM(date)
        ORDER BY (host, service, ts)
        TTL date + INTERVAL ${toString cfg.monitoring.clickhouse.retentionDays} DAY
        SETTINGS index_granularity = 8192
      "

      # 1分集計用のマテリアライズドビュー作成
      ${pkgs.clickhouse}/bin/clickhouse-client --query "
        CREATE MATERIALIZED VIEW IF NOT EXISTS logs.app_logs_1min
        ENGINE = SummingMergeTree()
        PARTITION BY toYYYYMM(date)
        ORDER BY (date, minute, host, service, unit)
        TTL date + INTERVAL ${toString cfg.monitoring.clickhouse.retentionDays} DAY
        AS
        SELECT
          toDate(ts) as date,
          toStartOfMinute(ts) as minute,
          host,
          service,
          unit,
          count() as cnt,
          countIf(level = 'error' OR level = 'ERROR') as err,
          countIf(status >= 500 AND status < 600) as s5xx,
          avg(latency_ms) as avg_latency,
          quantile(0.95)(latency_ms) as p95_latency,
          quantile(0.99)(latency_ms) as p99_latency,
          max(latency_ms) as max_latency
        FROM logs.${cfg.monitoring.clickhouse.logsTableName}
        GROUP BY date, minute, host, service, unit
      "

      # 異常検知結果保存用テーブル
      ${pkgs.clickhouse}/bin/clickhouse-client --query "
        CREATE TABLE IF NOT EXISTS logs.${cfg.monitoring.clickhouse.anomaliesTableName} (
          detected_at DateTime64(3),
          window_start DateTime64(3),
          window_end DateTime64(3),
          host String,
          service String,
          anomaly_type String,
          score Float32,
          details String,  -- JSON
          
          date Date DEFAULT toDate(detected_at)
        )
        ENGINE = MergeTree()
        PARTITION BY toYYYYMM(date)
        ORDER BY (detected_at, score)
        TTL date + INTERVAL 30 DAY
        SETTINGS index_granularity = 8192
      "

      echo "ClickHouse tables and views initialized successfully"
    '';
  };

  # systemdサービスの設定
  systemd.services.clickhouse = {
    serviceConfig = {
      # メモリ制限（高スペックマシンなので余裕を持たせる）
      MemoryMax = "10G";
      MemoryHigh = "8G";
      # CPU制限なし（高負荷処理を許可）
      CPUQuota = "";
      # 再起動ポリシー
      Restart = lib.mkForce "on-failure";
      RestartSec = "10s";
      # データディレクトリの作成
      StateDirectory = "clickhouse";
      StateDirectoryMode = "0750";

      # ログディレクトリの作成（既存の設定を上書き）
      LogsDirectory = lib.mkForce "clickhouse-server";
      LogsDirectoryMode = "0750";
    };
  };

  # Lokiからのデータ取り込みスクリプト
  systemd.services.loki-to-clickhouse = {
    description = "Import logs from Loki to ClickHouse";
    after = [
      "clickhouse.service"
      "network.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "clickhouse";
      Group = "clickhouse";
    };

    script = ''
      # Lokiから過去5分のログを取得してClickHouseに挿入
      # （実装はPythonスクリプトで行う予定）
      echo "Importing logs from Loki to ClickHouse..."
      # TODO: Python実装を追加
    '';
  };

  # 定期実行用タイマー（5分ごと）
  systemd.timers.loki-to-clickhouse = {
    description = "Timer for Loki to ClickHouse import";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "loki-to-clickhouse.service";
    };
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [
    cfg.monitoring.clickhouse.port # HTTP API
    cfg.monitoring.clickhouse.nativePort # Native protocol
  ];

  # 必要なパッケージ
  environment.systemPackages = with pkgs; [
    clickhouse
    python3
    python3Packages.clickhouse-driver
    python3Packages.requests
  ];
}


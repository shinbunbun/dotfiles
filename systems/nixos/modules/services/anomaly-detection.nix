/*
  異常検知ジョブ設定モジュール

  このモジュールは以下の機能を提供します：
  - Python異常検知スクリプトの定期実行
  - Isolation Forestによる統計的異常検知
  - 異常スコアのClickHouse保存
  - 5分ごとの自動実行

  使用方法:
  - nixos-desktopにインポートして使用
  - ClickHouseモジュールと併用
  - 高負荷な機械学習処理を実行
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

  # Python環境の定義
  pythonEnv = pkgs.python3.withPackages (
    ps: with ps; [
      clickhouse-driver
      numpy
      scikit-learn
      requests
    ]
  );

  # 異常検知スクリプト
  anomalyDetectionScript = ./anomaly-detection.py;

  # Loki→ClickHouse転送スクリプト
  lokiToClickhouseScript = ./loki-to-clickhouse.py;
in
{
  # 異常検知サービス
  systemd.services.anomaly-detection = {
    description = "Log anomaly detection with Isolation Forest";
    after = [
      "clickhouse.service"
      "network.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "clickhouse";
      Group = "clickhouse";

      # Python環境の設定
      Environment = [
        "PYTHONPATH=${pythonEnv}/${pythonEnv.sitePackages}"
        "PATH=${pythonEnv}/bin:$PATH"
      ];

      # リソース制限（ML処理のため余裕を持たせる）
      MemoryMax = "4G";
      MemoryHigh = "3G";
      CPUQuota = "200%";

      # エラー時の再起動
      Restart = "on-failure";
      RestartSec = "30s";

      # タイムアウト設定（5分）
      TimeoutStartSec = "300s";
    };

    script = ''
      echo "Starting anomaly detection at $(date)"
      ${pythonEnv}/bin/python3 ${anomalyDetectionScript}
      echo "Anomaly detection completed at $(date)"
    '';
  };

  # 定期実行用タイマー（5分ごと）
  systemd.timers.anomaly-detection = {
    description = "Timer for anomaly detection";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "10m"; # 起動後10分で初回実行
      OnUnitActiveSec = "5m"; # 5分ごとに実行
      Unit = "anomaly-detection.service";

      # タイマーの精度（1分の誤差を許容）
      AccuracySec = "1m";

      # システムがサスペンドから復帰した場合も実行
      Persistent = true;
    };
  };

  # Lokiデータ取り込みサービス
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

      Environment = [
        "PYTHONPATH=${pythonEnv}/${pythonEnv.sitePackages}"
        "PATH=${pythonEnv}/bin:$PATH"
      ];

      MemoryMax = "2G";
      CPUQuota = "100%";

      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "120s";
    };

    script = ''
      echo "Importing logs from Loki to ClickHouse at $(date)"

      # 環境変数を設定してPythonスクリプトを実行
      # Lokiはhomemachine(192.168.1.3)で動作している
      export LOKI_URL="http://192.168.1.3:${toString cfg.monitoring.loki.port}"
      export CLICKHOUSE_HOST="localhost"
      export CLICKHOUSE_PORT="${toString cfg.monitoring.clickhouse.nativePort}"

      ${pythonEnv}/bin/python3 ${lokiToClickhouseScript}

      echo "Log import completed at $(date)"
    '';
  };

  # Lokiデータ取り込みタイマー（5分ごと）
  systemd.timers.loki-to-clickhouse = {
    description = "Timer for Loki to ClickHouse import";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "loki-to-clickhouse.service";
      AccuracySec = "30s";
      Persistent = true;
    };
  };

  # 必要なパッケージ
  environment.systemPackages = [
    pythonEnv
  ];
}


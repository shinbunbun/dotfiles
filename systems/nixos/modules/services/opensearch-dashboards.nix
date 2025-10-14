/*
  OpenSearch Dashboards設定モジュール（Docker版）

  このモジュールは以下の機能を提供します：
  - OpenSearch Dashboards: ログ検索・可視化UI（Docker コンテナ）
  - OpenSearchとの連携
  - ダッシュボード作成機能
  - Dev Tools（クエリエディタ）
  - Discover（ログエクスプローラー）
  - Visualize（可視化）
  - 内部ネットワークからのアクセス

  使用方法:
  - nixos-desktopにインポートして使用
  - ブラウザから http://192.168.1.4:5601 でアクセス
  - OpenSearchのデータを可視化

  技術仕様:
  - 公式Dockerイメージ: opensearchproject/opensearch-dashboards:2.19.2
  - virtualisation.oci-containersで宣言的に管理
  - ヘルスチェック機能付き
  - 自動起動設定
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
  # Dockerバックエンドを有効化
  virtualisation.docker.enable = true;

  # OpenSearch Dashboards OCI Container
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      opensearch-dashboards = {
        image = "opensearchproject/opensearch-dashboards:2.19.2";
        autoStart = true;

        # ポート設定
        ports = [
          "${toString cfg.opensearchDashboards.port}:5601"
        ];

        # 環境変数設定
        environment = {
          # OpenSearch接続設定
          OPENSEARCH_HOSTS = cfg.opensearchDashboards.opensearchUrl;

          # セキュリティプラグイン無効化（内部ネットワーク限定）
          DISABLE_SECURITY_DASHBOARDS_PLUGIN = "true";

          # サーバー設定
          SERVER_HOST = "0.0.0.0";
          SERVER_NAME = "${cfg.opensearch.nodeName}-dashboards";

          # ログレベル
          LOGGING_VERBOSE = "false";
        };

        # 追加オプション
        extraOptions = [
          # ヘルスチェック設定
          "--health-cmd=curl -f http://localhost:5601/api/status || exit 1"
          "--health-interval=30s"
          "--health-timeout=10s"
          "--health-retries=3"
          "--health-start-period=60s"

          # ネットワーク設定
          "--add-host=host.docker.internal:host-gateway"
        ];
      };
    };
  };

  # systemdサービスの追加設定
  systemd.services.docker-opensearch-dashboards = {
    # OpenSearchサービスに依存
    after = [ "opensearch.service" ];
    requires = [ "opensearch.service" ];

    # サービス設定
    serviceConfig = {
      # 再起動ポリシー
      Restart = lib.mkForce "on-failure";
      RestartSec = lib.mkForce "30s";

      # タイムアウト設定
      TimeoutStartSec = lib.mkForce "300s";
      TimeoutStopSec = lib.mkForce "60s";
    };
  };

  # 初期化待機サービス（オプション）
  systemd.services.opensearch-dashboards-wait = {
    description = "Wait for OpenSearch Dashboards to be ready";
    after = [ "docker-opensearch-dashboards.service" ];
    wants = [ "docker-opensearch-dashboards.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "opensearch-dashboards-wait" ''
        echo "Waiting for OpenSearch Dashboards to be ready..."
        for i in {1..60}; do
          if ${pkgs.curl}/bin/curl -f http://localhost:${toString cfg.opensearchDashboards.port}/api/status > /dev/null 2>&1; then
            echo "OpenSearch Dashboards is ready!"
            exit 0
          fi
          echo "Attempt $i/60: OpenSearch Dashboards not ready yet, waiting..."
          sleep 5
        done
        echo "Warning: OpenSearch Dashboards did not become ready within timeout"
        exit 1
      '';
    };
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [
    cfg.opensearchDashboards.port
  ];

  # 必要なパッケージ
  environment.systemPackages = with pkgs; [
    docker
    curl
  ];

  # ログローテーション設定（Dockerログ）
  services.logrotate.settings.docker-opensearch-dashboards = {
    files = "/var/lib/docker/containers/*-opensearch-dashboards*/*.log";
    rotate = 7;
    frequency = "daily";
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
  };
}

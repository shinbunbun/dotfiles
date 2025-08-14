/*
  Promtailログ収集エージェント設定モジュール

  このモジュールは以下の機能を提供します：
  - systemd-journaldからのログ収集
  - Nginxアクセスログ・エラーログの収集
  - アプリケーションログの収集
  - Lokiへのログ転送
  - 構造化ログのパース

  使用方法:
  - 各ホストにインポートして使用
  - Lokiサーバーのアドレスは自動的にhomeMachineを参照
  - journaldとファイルベースのログを自動収集
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

  # ホスト名の取得
  hostname = config.networking.hostName;

  # Lokiサーバーのアドレス
  lokiUrl = "http://${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain}:${toString cfg.monitoring.loki.port}";
in
{
  # Promtail設定
  services.promtail = {
    enable = true;

    configuration = {
      # サーバー設定
      server = {
        http_listen_port = cfg.monitoring.promtail.port;
        grpc_listen_port = 0;
      };

      # ポジションファイル（読み取り位置の記録）
      positions = {
        filename = cfg.monitoring.promtail.positionsFile;
      };

      # Lokiクライアント設定
      clients = [
        {
          url = "${lokiUrl}/loki/api/v1/push";
          # バックプレッシャー設定
          batchwait = "1s";
          batchsize = 1048576; # 1MB
          # タイムアウト設定
          timeout = "10s";
          # リトライ設定
          backoff_config = {
            min_period = "500ms";
            max_period = "5m";
            max_retries = 10;
          };
        }
      ];

      # スクレイプ設定
      scrape_configs = [
        # systemd-journaldからのログ収集
        {
          job_name = "journal";
          journal = {
            # journaldのパス
            path = "/var/log/journal";
            # 最大経過時間
            max_age = "12h";
            # ラベル
            labels = {
              job = "systemd-journal";
              host = hostname;
            };
          };
          # リラベル設定
          relabel_configs = [
            # ユニット名をラベルとして追加
            {
              source_labels = [ "__journal__systemd_unit" ];
              target_label = "unit";
            }
            # サービス名をラベルとして追加
            {
              source_labels = [ "__journal__systemd_unit" ];
              regex = "([^.]+)\\.service";
              target_label = "service";
              replacement = "\${1}";
            }
            # ログレベルをラベルとして追加（優先度をマッピング）
            {
              source_labels = [ "__journal_priority" ];
              regex = "0";
              target_label = "level";
              replacement = "emergency";
            }
            {
              source_labels = [ "__journal_priority" ];
              regex = "1";
              target_label = "level";
              replacement = "alert";
            }
            {
              source_labels = [ "__journal_priority" ];
              regex = "2";
              target_label = "level";
              replacement = "critical";
            }
            {
              source_labels = [ "__journal_priority" ];
              regex = "3";
              target_label = "level";
              replacement = "error";
            }
            {
              source_labels = [ "__journal_priority" ];
              regex = "4";
              target_label = "level";
              replacement = "warning";
            }
            {
              source_labels = [ "__journal_priority" ];
              regex = "5";
              target_label = "level";
              replacement = "notice";
            }
            {
              source_labels = [ "__journal_priority" ];
              regex = "6";
              target_label = "level";
              replacement = "info";
            }
            {
              source_labels = [ "__journal_priority" ];
              regex = "7";
              target_label = "level";
              replacement = "debug";
            }
          ];
          # パイプライン設定（ログの処理）
          pipeline_stages = [
            # タイムスタンプの抽出
            {
              timestamp = {
                source = "__journal__realtime_timestamp";
                format = "UnixNs";
              };
            }
            # ラベルの設定
            {
              labels = {
                unit = null;
                service = null;
                level = null;
              };
            }
            # 出力フォーマット
            {
              output = {
                source = "message";
              };
            }
          ];
        }
      ]
      ++ lib.optionals (config.services.nginx.enable or false) [
        # Nginxアクセスログの収集（nginxが有効な場合のみ）
        {
          job_name = "nginx_access";
          static_configs = [
            {
              targets = [ "localhost" ];
              labels = {
                job = "nginx";
                host = hostname;
                __path__ = "/var/log/nginx/access.log";
                log_type = "access";
              };
            }
          ];
          pipeline_stages = [
            # 正規表現でパース
            {
              regex = {
                expression = ''^(?P<remote_addr>[^\s]+) - (?P<remote_user>[^\s]+) \[(?P<time_local>[^\]]+)\] "(?P<request>[^"]+)" (?P<status>\d+) (?P<body_bytes_sent>\d+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)"'';
              };
            }
            # ラベルの追加
            {
              labels = {
                status = null;
                method = null;
              };
            }
            # メソッドの抽出
            {
              regex = {
                source = "request";
                expression = "^(?P<method>\\w+)";
              };
            }
            # メトリクスの生成
            {
              metrics = {
                http_nginx_response_total = {
                  type = "Counter";
                  description = "Total number of HTTP requests";
                  source = "status";
                  config = {
                    action = "inc";
                  };
                };
              };
            }
          ];
        }

        # Nginxエラーログの収集（nginxが有効な場合のみ）
        {
          job_name = "nginx_error";
          static_configs = [
            {
              targets = [ "localhost" ];
              labels = {
                job = "nginx";
                host = hostname;
                __path__ = "/var/log/nginx/error.log";
                log_type = "error";
              };
            }
          ];
          pipeline_stages = [
            # エラーレベルの抽出
            {
              regex = {
                expression = ''^\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} \[(?P<level>\w+)\]'';
              };
            }
            {
              labels = {
                level = null;
              };
            }
          ];
        }
      ]
      ++ [
        # アプリケーションログの収集（JSON形式）
        {
          job_name = "application";
          static_configs = [
            {
              targets = [ "localhost" ];
              labels = {
                job = "application";
                host = hostname;
                __path__ = "/var/log/application/*.json";
              };
            }
          ];
          pipeline_stages = [
            # JSON パース
            {
              json = {
                expressions = {
                  level = "level";
                  service = "service";
                  trace_id = "trace_id";
                  message = "message";
                  timestamp = "timestamp";
                };
              };
            }
            # タイムスタンプの処理
            {
              timestamp = {
                source = "timestamp";
                format = "RFC3339";
              };
            }
            # ラベルの設定
            {
              labels = {
                level = null;
                service = null;
              };
            }
            # メトリクスの生成
            {
              metrics = {
                app_errors_total = {
                  type = "Counter";
                  description = "Total number of application errors";
                  source = "level";
                  config = {
                    action = "inc";
                    match_all = false;
                    count_entry_bytes = false;
                  };
                };
              };
            }
          ];
        }
      ];
    };
  };

  # systemdサービスの設定
  systemd.services.promtail = {
    serviceConfig = {
      # 権限設定（nginxが有効な場合のみnginxグループを追加）
      SupplementaryGroups = [
        "systemd-journal"
      ]
      ++ lib.optional (config.services.nginx.enable or false) "nginx";
      # メモリ制限
      MemoryMax = "256M";
      MemoryHigh = "128M";
      # CPU制限
      CPUQuota = "50%";
      # 再起動ポリシー
      Restart = "on-failure";
      RestartSec = "5s";
      # データディレクトリの作成
      StateDirectory = "promtail";
      StateDirectoryMode = "0750";
    };
  };

  # ファイアウォール設定（メトリクス用）
  networking.firewall.allowedTCPPorts = [
    cfg.monitoring.promtail.port # Promtailメトリクス
  ];

  # システムパッケージにPromtailを追加
  environment.systemPackages = with pkgs; [
    promtail
  ];
}

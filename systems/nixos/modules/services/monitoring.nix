/*
  監視システム設定モジュール

  このモジュールは以下の監視コンポーネントを設定します：
  - Prometheus: メトリクス収集と保存
  - Node Exporter: システムメトリクスの公開
  - Grafana: メトリクスの可視化
  - Alertmanager: アラート管理とDiscord通知

  外部アクセスはCloudflare Tunnel経由で提供されます。
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
  # Prometheus設定
  services.prometheus = {
    enable = true;
    port = cfg.monitoring.prometheus.port;

    # データ保持期間を30日に設定
    retentionTime = "${toString cfg.monitoring.prometheus.retentionDays}d";

    # グローバル設定
    globalConfig = {
      scrape_interval = cfg.monitoring.prometheus.scrapeInterval;
      evaluation_interval = cfg.monitoring.prometheus.evaluationInterval;
    };

    # スクレイプ設定
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:${toString cfg.monitoring.nodeExporter.port}" ];
            labels = {
              instance = "${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain}";
            };
          }
          {
            targets = [
              "${cfg.networking.hosts.nixosDesktop.ip}:${toString cfg.monitoring.nodeExporter.port}"
            ];
            labels = {
              instance = cfg.networking.hosts.nixosDesktop.hostname;
            };
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "localhost:${toString cfg.monitoring.prometheus.port}" ];
          }
        ];
      }
      {
        job_name = "routeros";
        static_configs = [
          {
            targets = [ "${cfg.routerosBackup.routerIP}" ]; # RouterOSのIPアドレス
          }
        ];
        metrics_path = "/snmp";
        params = {
          module = [ "mikrotik" ];
          auth = [ "public_v2" ];
        };
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "__param_target";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "localhost:${toString cfg.monitoring.snmpExporter.port}"; # SNMP Exporter
          }
        ];
      }
    ];
  };

  # Node Exporter設定
  services.prometheus.exporters.node = {
    enable = true;
    port = cfg.monitoring.nodeExporter.port;
    enabledCollectors = [
      "cpu"
      "diskstats"
      "filesystem"
      "loadavg"
      "meminfo"
      "netdev"
      "stat"
      "time"
      "vmstat"
      "systemd"
      "processes"
      "hwmon" # ハードウェアモニタリング（電圧、ファン、温度）
      "thermal_zone" # サーマルゾーン（CPU温度）
      "interrupts" # IRQ詳細統計
      "powersupplyclass" # 電源供給統計
      "tcpstat" # TCP接続状態統計
    ];
    extraFlags = [
      "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/user/.+)($|/)"
      "--collector.netdev.device-exclude=^(veth.*|br.*|docker.*|virbr.*|lo|wlp[12]s0)$"
    ];
  };

  # SNMP Exporter設定
  services.prometheus.exporters.snmp = {
    enable = true;
    port = cfg.monitoring.snmpExporter.port;
    configurationPath = ./snmp.yml;
  };

  # Grafana設定
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = cfg.monitoring.grafana.port;
        domain = cfg.monitoring.grafana.domain;
        root_url = "https://${cfg.monitoring.grafana.domain}";
      };

      security = {
        admin_user = "admin";
        # 初期パスワードは初回ログイン後に変更必須
        admin_password = "admin";
        # 自動ログインを無効化（OAuth2使用時）
        disable_initial_admin_creation = false;
      };

      # 匿名アクセスを無効化
      "auth.anonymous" = {
        enabled = false;
      };

      # OAuth2/OIDC認証設定（Authentik）
      "auth.generic_oauth" = {
        enabled = true;
        name = "Authentik";
        allow_sign_up = true;
        client_id = "$__env{GRAFANA_OAUTH_CLIENT_ID}";
        client_secret = "$__env{GRAFANA_OAUTH_CLIENT_SECRET}";
        scopes = "openid email profile";
        auth_url = "${cfg.authentik.baseUrl}/application/o/authorize/";
        token_url = "${cfg.authentik.baseUrl}/application/o/token/";
        api_url = "${cfg.authentik.baseUrl}/application/o/userinfo/";
        # ロールマッピング
        role_attribute_path = "contains(groups[*], 'Grafana Admins') && 'Admin' || contains(groups[*], 'Grafana Editors') && 'Editor' || 'Viewer'";
        # 自動ログイン（Cloudflare経由のアクセス時）
        auto_login = true;
      };

      # 基本設定
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
      };
    };

    # Prometheusデータソースの自動設定
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://localhost:${toString cfg.monitoring.prometheus.port}";
          jsonData = {
            timeInterval = cfg.monitoring.prometheus.scrapeInterval;
          };
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://localhost:${toString cfg.monitoring.loki.port}";
          jsonData = {
            maxLines = 1000;
            derivedFields = [
              {
                # trace_idフィールドからトレースリンクを生成
                datasourceName = "Jaeger";
                matcherRegex = "trace_id=(\\w+)";
                name = "TraceID";
                url = "$${__value.raw}";
              }
            ];
          };
        }
      ];

      # 基本ダッシュボードの設定
      dashboards.settings.providers = [
        {
          name = "default";
          orgId = 1;
          folder = "";
          type = "file";
          disableDeletion = false;
          updateIntervalSeconds = 10;
          allowUiUpdates = true;
          options = {
            path = ./dashboards;
          };
        }
      ];
    };
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [
    cfg.monitoring.prometheus.port # Prometheus (内部アクセスのみ)
    cfg.monitoring.nodeExporter.port # Node Exporter (内部アクセスのみ)
    cfg.monitoring.grafana.port # Grafana (Cloudflare Tunnel経由)
    cfg.monitoring.snmpExporter.port # SNMP Exporter (内部アクセスのみ)
  ];

  # Grafana用の環境変数設定
  systemd.services.grafana.serviceConfig = {
    EnvironmentFile = [ config.sops.templates."grafana/oauth-env".path ];
  };

  # システムパッケージにPrometheusツールを追加
  environment.systemPackages = [
    pkgs.prometheus
    pkgs.prometheus-node-exporter
    pkgs.prometheus-snmp-exporter
    pkgs.grafana
    pkgs.net-snmp # snmpwalkなどのツール
  ];

  # Cloudflare Tunnel用のSOPS secrets設定
  sops = {
    secrets."monitoring_cloudflare_account_tag" = {
      key = "cloudflare/account_tag";
      sopsFile = "${inputs.self}/secrets/monitoring.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."monitoring_cloudflare_tunnel_secret" = {
      key = "cloudflare/tunnel_secret";
      sopsFile = "${inputs.self}/secrets/monitoring.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."monitoring_cloudflare_tunnel_id" = {
      key = "cloudflare/tunnel_id";
      sopsFile = "${inputs.self}/secrets/monitoring.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # Grafana OAuth環境変数
    secrets."grafana/oauth_client_id" = {
      sopsFile = "${inputs.self}/secrets/grafana.yaml";
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };

    secrets."grafana/oauth_client_secret" = {
      sopsFile = "${inputs.self}/secrets/grafana.yaml";
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };

    templates."grafana/oauth-env" = {
      content = ''
        GRAFANA_OAUTH_CLIENT_ID=${config.sops.placeholder."grafana/oauth_client_id"}
        GRAFANA_OAUTH_CLIENT_SECRET=${config.sops.placeholder."grafana/oauth_client_secret"}
      '';
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };

    # Cloudflare credentials file template
    templates."monitoring/cloudflare/credentials.json" = {
      content = builtins.toJSON {
        AccountTag = config.sops.placeholder."monitoring_cloudflare_account_tag";
        TunnelSecret = config.sops.placeholder."monitoring_cloudflare_tunnel_secret";
        TunnelID = config.sops.placeholder."monitoring_cloudflare_tunnel_id";
      };
      path = "/run/secrets/rendered/monitoring/cloudflare/credentials.json";
      owner = "root";
      group = "root";
      mode = "0640";
    };
  };

}

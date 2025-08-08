# cells/core/nixosProfiles/monitoring.nix
/*
  監視システム設定モジュール

  このモジュールは以下の監視コンポーネントを設定します：
  - Prometheus: メトリクス収集と保存
  - Node Exporter: システムメトリクスの公開
  - Grafana: メトリクスの可視化
  - Alertmanager: アラート管理とDiscord通知

  外部アクセスはCloudflare Tunnel経由で提供されます。
*/
{ inputs, cell }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # config.nixから設定を読み込み
  cfg = import ../config.nix;
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
    ];
    extraFlags = [
      "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|run/user/.+)($|/)"
      "--collector.netdev.device-exclude=^(veth.*|br.*|docker.*|virbr.*|lo|wlp1s0)$"
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
      };

      # 匿名アクセスを無効化
      "auth.anonymous" = {
        enabled = false;
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

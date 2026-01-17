/*
  オブザーバビリティ設定 - homeMachine

  このファイルは nixos-observability モジュールを使用した監視スタックの設定を定義します：
  - Prometheus: メトリクス収集
  - Grafana: 可視化とダッシュボード
  - Node Exporter: システムメトリクス
  - SNMP Exporter: RouterOS 監視
*/
{
  config,
  inputs,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;
in
{
  # SOPS設定（Grafana OAuth）
  sops = {
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
  };

  # オブザーバビリティ設定（nixos-observability）
  services.observability.monitoring = {
    enable = true;

    # Prometheus設定
    prometheus = {
      enable = true;
      port = cfg.monitoring.prometheus.port;
      retentionDays = cfg.monitoring.prometheus.retentionDays;
      scrapeInterval = cfg.monitoring.prometheus.scrapeInterval;
      evaluationInterval = cfg.monitoring.prometheus.evaluationInterval;

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
              targets = [ cfg.routerosBackup.routerIP ];
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
              replacement = "localhost:${toString cfg.monitoring.snmpExporter.port}";
            }
          ];
        }
      ];
    };

    # Node Exporter設定
    nodeExporter = {
      enable = true;
      port = cfg.monitoring.nodeExporter.port;
    };

    # SNMP Exporter設定
    snmpExporter = {
      enable = true;
      port = cfg.monitoring.snmpExporter.port;
      configFile = inputs.nixos-observability.assets.snmpConfig;
    };

    # Grafana設定
    grafana = {
      enable = true;
      port = cfg.monitoring.grafana.port;
      domain = cfg.monitoring.grafana.domain;

      oauth = {
        enable = true;
        name = "Authentik";
        environmentFile = config.sops.templates."grafana/oauth-env".path;
        authUrl = "${cfg.authentik.baseUrl}/application/o/authorize/";
        tokenUrl = "${cfg.authentik.baseUrl}/application/o/token/";
        apiUrl = "${cfg.authentik.baseUrl}/application/o/userinfo/";
        roleAttributePath = "contains(groups[*], 'Grafana Admins') && 'Admin' || contains(groups[*], 'Grafana Editors') && 'Editor' || 'Viewer'";
        autoLogin = true;
      };

      dashboards = {
        enable = true;
        path = inputs.nixos-observability.assets.dashboards;
      };
    };

    # データソース設定
    datasources = {
      prometheus = {
        enable = true;
        isDefault = true;
      };

      loki = {
        enable = true;
        url = "http://localhost:${toString cfg.monitoring.loki.port}";
      };
    };
  };
}

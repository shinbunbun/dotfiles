/*
  オブザーバビリティ設定 - homeMachine

  このファイルは nixos-observability モジュールを使用した監視スタックの設定を定義します：
  - Prometheus: メトリクス収集
  - Grafana: 可視化とダッシュボード
  - Node Exporter: システムメトリクス
  - SNMP Exporter: RouterOS 監視
  - Loki: ログ集約
  - Alertmanager: アラート管理
  - Fluent Bit: ログ収集
*/
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;

  # Fluent Bit設定ファイル生成
  fluentBitConfigs = import inputs.nixos-observability-config.lib.fluentBit.generator {
    inherit pkgs;
    inherit cfg;
    hostname = config.networking.hostName;
  };
in
{
  # SOPS設定
  sops = {
    # Grafana OAuth
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

    # Grafana secret_key（データソース設定の署名に使用）
    secrets."grafana/secret_key" = {
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

    # Alertmanager Discord
    secrets."alertmanager/discord_webhook_url" = {
      key = "discord/webhook_url";
      sopsFile = "${inputs.self}/secrets/alertmanager.yaml";
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };

    secrets."alertmanager/discord_user_id" = {
      key = "discord/user_id";
      sopsFile = "${inputs.self}/secrets/alertmanager.yaml";
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };

    templates."alertmanager/env" = {
      content = ''
        DISCORD_WEBHOOK_URL=${config.sops.placeholder."alertmanager/discord_webhook_url"}
        DISCORD_USER_ID=${config.sops.placeholder."alertmanager/discord_user_id"}
      '';
      path = "/run/secrets/rendered/alertmanager/env";
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };
  };

  # Grafana secret_key設定（nixpkgsでデフォルト値が削除されたため明示的に設定が必要）
  services.grafana.settings.security.secret_key = "$__file{${config.sops.secrets."grafana/secret_key".path}}";

  # オブザーバビリティ設定（nixos-observability）
  services.observability = {
    # Alertmanager設定
    alertmanager = {
      enable = true;
      port = cfg.monitoring.alertmanager.port;
      discord.webhookUrlFile = config.sops.templates."alertmanager/env".path;

      # アラートルールを読み込み
      alertRules = import inputs.nixos-observability-config.assets.alertRules;

      prometheusUrl = "localhost:${toString cfg.monitoring.alertmanager.port}";
      externalUrl = "https://${cfg.monitoring.grafana.domain}";
    };

    # Fluent Bit設定
    fluentBit = {
      enable = true;
      port = cfg.fluentBit.port;
      configFile = fluentBitConfigs.main;
      firewallPorts = [ cfg.fluentBit.syslogPort ]; # syslog UDP port
      openFirewall = true;
    };

    # Loki設定
    loki = {
      enable = true;
      port = cfg.monitoring.loki.port;
      dataDir = cfg.monitoring.loki.dataDir;
      retentionDays = cfg.monitoring.loki.retentionDays;
      ingestionRateLimit = cfg.monitoring.loki.ingestionRateLimit;
      ingestionBurstSize = cfg.monitoring.loki.ingestionBurstSize;
      chunkTargetSize = cfg.monitoring.loki.chunkTargetSize;
      alertmanagerUrl = "http://localhost:${toString cfg.monitoring.alertmanager.port}";
      rulesFile = inputs.nixos-observability-config.assets.lokiRules;
      externalUrl = "https://${cfg.monitoring.grafana.domain}";
    };

    # Monitoring設定
    monitoring = {
      enable = true;

      # Prometheus設定
      prometheus = {
        enable = true;
        port = cfg.monitoring.prometheus.port;
        retentionDays = cfg.monitoring.prometheus.retentionDays;
        scrapeInterval = cfg.monitoring.prometheus.scrapeInterval;
        evaluationInterval = cfg.monitoring.prometheus.evaluationInterval;
        externalUrl = "https://${cfg.monitoring.grafana.domain}";

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
        configFile = inputs.nixos-observability-config.assets.snmpConfig;
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
          path = inputs.nixos-observability-config.assets.dashboards;
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
  };
}

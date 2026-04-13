/*
  オブザーバビリティ設定 - homeMachine

  このファイルは nixos-observability モジュールを使用した監視スタックの設定を定義します：
  - Node Exporter: システムメトリクス
  - Loki: ログ集約
  - Fluent Bit: ログ収集

  Prometheus, Alertmanager, SNMP Exporter は k3s クラスタ (k8s-apps) の
  VictoriaMetrics スタックに移管済み。
  可視化（Grafana）も k3s クラスタ (k8s-apps/infrastructure/grafana) に移管済み。
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
  # オブザーバビリティ設定（nixos-observability）
  services.observability = {
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
      alertmanagerUrl = "http://${cfg.monitoring.alertmanager.vip}:${toString cfg.monitoring.alertmanager.port}";
      rulesFile = inputs.nixos-observability-config.assets.lokiRules;
      externalUrl = "https://${cfg.monitoring.grafana.domain}";
    };

    # Monitoring設定（Node Exporter のみ有効化）
    monitoring = {
      enable = true;

      prometheus.enable = false;
      snmpExporter.enable = false;

      # Node Exporter設定
      nodeExporter = {
        enable = true;
        port = cfg.monitoring.nodeExporter.port;
      };
    };
  };
}

/*
  オブザーバビリティ設定 - homeMachine

  このファイルは nixos-observability モジュールを使用した監視スタックの設定を定義します：
  - Node Exporter: システムメトリクス
  - Fluent Bit: ログ収集 (k3s 上の Loki へ送信)

  Prometheus, Alertmanager, SNMP Exporter は k3s クラスタ (k8s-apps) の
  VictoriaMetrics スタックに移管済み。
  可視化（Grafana）も k3s クラスタ (k8s-apps/infrastructure/grafana) に移管済み。
  Loki も k3s クラスタ (k8s-apps/infrastructure/loki) に移管済み。
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

    # Monitoring設定（Node Exporter のみ）
    monitoring = {
      enable = true;

      nodeExporter = {
        enable = true;
        port = cfg.monitoring.nodeExporter.port;
      };
    };
  };
}

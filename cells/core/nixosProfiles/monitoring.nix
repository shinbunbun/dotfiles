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
      "--collector.netdev.device-exclude=^(veth.*|br.*|docker.*|virbr.*|lo)$"
    ];
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [
    cfg.monitoring.prometheus.port # Prometheus (内部アクセスのみ)
    cfg.monitoring.nodeExporter.port # Node Exporter (内部アクセスのみ)
  ];

  # システムパッケージにPrometheusツールを追加
  environment.systemPackages = [
    pkgs.prometheus
    pkgs.prometheus-node-exporter
  ];
}

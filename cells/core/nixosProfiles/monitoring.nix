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
  cfg = config.services;
in
{
  # Prometheus設定
  services.prometheus = {
    enable = true;
    port = 9090;

    # データ保持期間を30日に設定
    retentionTime = "30d";

    # グローバル設定
    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    # スクレイプ設定
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:9100" ];
            labels = {
              instance = "nixos.shinbunbun.com";
            };
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "localhost:9090" ];
          }
        ];
      }
    ];
  };

  # Node Exporter設定
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
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
    9090 # Prometheus (内部アクセスのみ)
    9100 # Node Exporter (内部アクセスのみ)
  ];

  # システムパッケージにPrometheusツールを追加
  environment.systemPackages = with pkgs; [
    prometheus
    prometheus-node-exporter
  ];
}

/*
  オブザーバビリティ設定 - g3pro

  このファイルはg3proの監視設定を定義します：
  - Node Exporter: システムメトリクスの公開（homeMachineのPrometheusがスクレイプ）
  - Fluent Bit: systemd-journalログをhomeMachineのLoki/OpenSearchへ転送

  Fluent Bitは nixos-observability-config の generator を使用し、
  homeMachineと同じフォーマットでログを転送します。
*/
{
  config,
  inputs,
  pkgs,
  ...
}:

let
  cfg = import ../../../../shared/config.nix;

  # Fluent Bit設定ファイル生成（nixos-observability-config の generator を使用）
  fluentBitConfigs = import inputs.nixos-observability-config.lib.fluentBit.generator {
    inherit pkgs;
    inherit cfg;
    hostname = config.networking.hostName;
  };
in
{
  # Node Exporter（NixOS組み込み）
  # homeMachineのPrometheusがこのエンドポイントをスクレイプする
  services.prometheus.exporters.node = {
    enable = true;
    port = cfg.monitoring.nodeExporter.port;
    openFirewall = true;
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

  # Fluent Bit設定（nixos-observability モジュール経由）
  # systemd-journal → Loki + OpenSearch へログ転送
  # syslog入力も含まれるが、RouterOSからの送信がないためidle
  services.observability.fluentBit = {
    enable = true;
    port = cfg.fluentBit.port;
    configFile = fluentBitConfigs.main;
    # syslogポートのファイアウォールは開けない（g3proではRouterOSログを受信しない）
    openFirewall = false;
  };
}

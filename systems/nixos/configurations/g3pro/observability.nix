/*
  オブザーバビリティ設定 - g3pro

  このファイルはg3proの監視設定を定義します：
  - Node Exporter: システムメトリクスの公開（k3s の vmagent がスクレイプ）
  - Process Exporter: プロセス別メトリクスの公開 (top 相当)
  - Fluent Bit: systemd-journalログを Loki / Vector (k3s) へ転送

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
  # k3s クラスタの vmagent がこのエンドポイントをスクレイプする
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

  # Process Exporter（nixos-observability モジュール経由、プロセス別メトリクス / top 相当）
  # node exporter は上で直書きしているため nodeExporter.enable = false で共存させる
  services.observability.monitoring = {
    enable = true;
    nodeExporter.enable = false;
    processExporter = {
      enable = true;
      port = cfg.monitoring.processExporter.port;
    };
  };

  # Fluent Bit設定（nixos-observability モジュール経由）
  # systemd-journal → Loki + Vector (k3s) へログ転送
  # syslog入力も含まれるが、RouterOSからの送信がないためidle
  services.observability.fluentBit = {
    enable = true;
    port = cfg.fluentBit.port;
    configFile = fluentBitConfigs.main;
    # syslogポートのファイアウォールは開けない（g3proではRouterOSログを受信しない）
    openFirewall = false;
  };
}

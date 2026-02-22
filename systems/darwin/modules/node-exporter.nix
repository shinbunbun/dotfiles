/*
  Darwin Node Exporter設定

  macOS用のPrometheus Node Exporterをlaunchdデーモンとして起動します。
  macOSで利用可能なコレクターのみ有効化し、仮想NICやシステムボリュームを除外します。
*/
{
  pkgs,
  ...
}:

let
  cfg = import ../../../shared/config.nix;
  nodeExporterPort = cfg.monitoring.nodeExporter.port;
in
{
  environment.systemPackages = [ pkgs.prometheus-node-exporter ];

  launchd.daemons.node-exporter = {
    serviceConfig = {
      Label = "org.prometheus.node-exporter";
      ProgramArguments = [
        "${pkgs.prometheus-node-exporter}/bin/node_exporter"
        "--collector.cpu"
        "--collector.diskstats"
        "--collector.filesystem"
        "--collector.loadavg"
        "--collector.meminfo"
        "--collector.netdev"
        "--collector.time"
        "--collector.boottime"
        "--collector.uname"
        "--web.listen-address=:${toString nodeExporterPort}"
        "--collector.filesystem.mount-points-exclude=^/(dev|System/Volumes/VM|System/Volumes/Preboot|System/Volumes/Update)($|/)"
        "--no-collector.thermal"
        "--collector.netdev.device-exclude=^(utun|awdl|llw|bridge|gif|stf|ap).*$"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/node-exporter.log";
      StandardErrorPath = "/var/log/node-exporter.error.log";
    };
  };
}

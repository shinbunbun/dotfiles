# shared/config.nix
/*
  中央設定モジュール

  このモジュールはシステム全体の設定値を一元管理します。
  各セクションはshared/sections/以下のファイルに分割されており、
  バリデーション関数はshared/validators.nixで定義されています。

  型チェックとアサーションを含み、設定エラーを
  早期に発見できるようにしています。このファイルを
  編集することで、システム全体の設定を一括で変更できます。
*/
let
  # バリデーション関数の読み込み
  v = import ./validators.nix;

  # 各セクションの読み込みと結合
  sections = builtins.foldl' (acc: section: acc // (import section v)) { } [
    ./sections/users.nix
    ./sections/system.nix
    ./sections/networking.nix
    ./sections/wireguard.nix
    ./sections/monitoring.nix
    ./sections/services.nix
    ./sections/management.nix
    ./sections/infrastructure.nix
  ];

  config = sections;

  # ポートレジストリ: 全ポートを一元管理し、衝突を自動検出
  portRegistry = [
    {
      name = "ssh";
      port = config.ssh.port;
    }
    {
      name = "networking.firewall.general";
      port = config.networking.firewall.generalPort;
    }
    {
      name = "networking.firewall.nfs";
      port = config.networking.firewall.nfsPort;
    }
    {
      name = "monitoring.prometheus";
      port = config.monitoring.prometheus.port;
    }
    {
      name = "monitoring.nodeExporter";
      port = config.monitoring.nodeExporter.port;
    }
    {
      name = "monitoring.grafana";
      port = config.monitoring.grafana.port;
    }
    {
      name = "monitoring.alertmanager";
      port = config.monitoring.alertmanager.port;
    }
    {
      name = "monitoring.snmpExporter";
      port = config.monitoring.snmpExporter.port;
    }
    {
      name = "monitoring.k3sMetrics.kubeStateMetrics";
      port = config.monitoring.k3sMetrics.kubeStateMetricsPort;
    }
    {
      name = "monitoring.k3sMetrics.kubelet";
      port = config.monitoring.k3sMetrics.kubeletPort;
    }
    {
      name = "monitoring.k3sMetrics.apiServer";
      port = config.monitoring.k3sMetrics.apiServerPort;
    }
    {
      name = "monitoring.loki";
      port = config.monitoring.loki.port;
    }
    {
      name = "couchdb";
      port = config.couchdb.port;
    }
    {
      name = "management.cockpit";
      port = config.management.cockpit.port;
    }
    {
      name = "management.ttyd";
      port = config.management.ttyd.port;
    }
    {
      name = "opensearch";
      port = config.opensearch.port;
    }
    {
      name = "opensearch.transport";
      port = config.opensearch.transportPort;
    }
    {
      name = "opensearchDashboards";
      port = config.opensearchDashboards.port;
    }
    {
      name = "fluentBit";
      port = config.fluentBit.port;
    }
    {
      name = "fluentBit.syslog";
      port = config.fluentBit.syslogPort;
    }
    {
      name = "attic";
      port = config.attic.port;
    }
    {
      name = "mlxLm";
      port = config.mlxLm.port;
    }
    {
      name = "peerIssuer";
      port = config.peerIssuer.listenPort;
    }
    {
      name = "peerIssuer.router";
      port = config.peerIssuer.routerPort;
    }
    {
      name = "jellyfin";
      port = config.jellyfin.port;
    }
  ];

  # ポート衝突の自動検出
  portsByNumber = builtins.groupBy (entry: builtins.toString entry.port) portRegistry;
  portConflicts = builtins.filter (group: builtins.length group > 1) (
    builtins.attrValues portsByNumber
  );
  portConflictMessages = map (
    group:
    let
      names = map (e: e.name) group;
      port = (builtins.head group).port;
    in
    "Port ${builtins.toString port} is used by multiple services: ${builtins.concatStringsSep ", " names}"
  ) portConflicts;

  # ビジネスロジックのアサーション
  assertions = [
    {
      assertion = config.ssh.port != 22;
      message = "SSH port should not use the default port 22 for security reasons";
    }
    {
      assertion =
        config.k3s.desktop.enable
        -> (config.k3s.desktop.role == "server" || config.k3s.desktop.role == "agent");
      message = "k3s role must be either 'server' or 'agent'";
    }
    {
      assertion =
        config.k3s.desktop.role == "agent"
        -> (builtins.hasAttr "serverAddr" config.k3s.desktop && config.k3s.desktop.serverAddr != "");
      message = "k3s agent mode requires serverAddr to be set";
    }
  ];

  # ポート衝突チェック
  checkedPortConflicts =
    if portConflicts == [ ] then
      config
    else
      throw "Port conflict detected:\n${builtins.concatStringsSep "\n" portConflictMessages}";

  # ビジネスロジックアサーションのチェック
  checkedConfig = builtins.foldl' (
    acc: assertion:
    if assertion.assertion then acc else throw "Config assertion failed: ${assertion.message}"
  ) checkedPortConflicts assertions;
in
checkedConfig

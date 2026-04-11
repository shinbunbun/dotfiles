/*
  監視システム設定セクション

  Prometheus、Node Exporter、Alertmanager、
  SNMP Exporter、k3sメトリクス、Lokiの設定を定義します。

  Grafana 本体の設定値は持ちません（k3s クラスタに移管済み）。
  外部公開 URL としての domain だけが externalUrl / Cloudflare Tunnel で
  参照されるため保持しています。
*/
v: {
  monitoring = {
    # Prometheus設定
    prometheus = {
      port = v.assertPort "monitoring.prometheus.port" 9090;
      retentionDays = v.assertPositiveInt "monitoring.prometheus.retentionDays" 30;
      scrapeInterval = v.assertString "monitoring.prometheus.scrapeInterval" "15s";
      evaluationInterval = v.assertString "monitoring.prometheus.evaluationInterval" "15s";
    };

    # Node Exporter設定
    nodeExporter = {
      port = v.assertPort "monitoring.nodeExporter.port" 9100;
    };

    # Grafana設定 (k3s 上の外部 URL のみ保持、本体は k3s クラスタでホスト)
    grafana = {
      domain = v.assertString "monitoring.grafana.domain" "grafana.shinbunbun.com";
    };

    # Alertmanager設定
    alertmanager = {
      port = v.assertPort "monitoring.alertmanager.port" 9093;
    };

    # SNMP Exporter設定
    snmpExporter = {
      port = v.assertPort "monitoring.snmpExporter.port" 9116;
      communityString = v.assertString "monitoring.snmpExporter.communityString" "prometheus";
    };

    # k3sメトリクス設定
    k3sMetrics = {
      kubeStateMetricsPort = v.assertPort "monitoring.k3sMetrics.kubeStateMetricsPort" 30080;
      kubeletPort = v.assertPort "monitoring.k3sMetrics.kubeletPort" 10250;
      apiServerPort = v.assertPort "monitoring.k3sMetrics.apiServerPort" 6444;
    };

    # Loki設定
    loki = {
      port = v.assertPort "monitoring.loki.port" 3100;
      retentionDays = v.assertPositiveInt "monitoring.loki.retentionDays" 30;
      ingestionRateLimit = v.assertPositiveInt "monitoring.loki.ingestionRateLimit" 52428800; # 50MB/s
      ingestionBurstSize = v.assertPositiveInt "monitoring.loki.ingestionBurstSize" 104857600; # 100MB
      chunkTargetSize = v.assertPositiveInt "monitoring.loki.chunkTargetSize" 1572864;
      dataDir = v.assertPath "monitoring.loki.dataDir" "/var/lib/loki";
    };
  };
}

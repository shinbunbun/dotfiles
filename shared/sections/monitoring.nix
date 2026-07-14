/*
  監視システム設定セクション

  NixOS 側で使用する監視設定値を定義します：
  - Node Exporter: 各ホストのシステムメトリクス公開
  - Process Exporter: 各ホストのプロセス別メトリクス公開 (top 相当)
  - Loki: Fluent Bit クライアントの送信先 (本体は k3s クラスタ)
  - Grafana: 外部 URL のみ保持（本体は k3s クラスタ）

  Prometheus / Alertmanager / SNMP Exporter / k3sメトリクス設定は
  k3s クラスタの VictoriaMetrics スタック (k8s-apps) に移管済み。
  Loki 本体も k3s クラスタ (k8s-apps/infrastructure/loki) に移管済み。
*/
v: {
  monitoring = {
    # Node Exporter設定
    nodeExporter = {
      port = v.assertPort "monitoring.nodeExporter.port" 9100;
    };

    # Process Exporter 設定 (プロセス別 CPU/メモリメトリクス公開、top 相当)
    processExporter = {
      port = v.assertPort "monitoring.processExporter.port" 9256;
    };

    # smartctl Exporter 設定 (ディスク SMART メトリクス公開)
    smartctlExporter = {
      port = v.assertPort "monitoring.smartctlExporter.port" 9633;
    };

    # Grafana設定 (k3s 上の外部 URL のみ保持、本体は k3s クラスタでホスト)
    grafana = {
      domain = v.assertString "monitoring.grafana.domain" "grafana.shinbunbun.com";
    };

    # Loki設定 (Fluent Bit クライアント参照用のみ、本体は k3s クラスタ)
    loki = {
      # k3s 上の loki-lan Service (Cilium LB IPAM 固定 VIP)
      host = v.assertString "monitoring.loki.host" "192.168.128.14";
      port = v.assertPort "monitoring.loki.port" 3100;
    };
  };
}

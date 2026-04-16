/*
  監視システム設定セクション

  NixOS 側で使用する監視設定値を定義します：
  - Node Exporter: 各ホストのシステムメトリクス公開
  - Loki: Fluent Bit クライアントの送信先 (本体は k3s クラスタ)
  - Grafana: 外部 URL のみ保持（本体は k3s クラスタ）
  - Alertmanager: k3s VMAlertmanager への LAN VIP 参照情報のみ保持

  Prometheus / SNMP Exporter / k3sメトリクス設定は
  k3s クラスタの VictoriaMetrics スタック (k8s-apps) に移管済み。
  Loki 本体も k3s クラスタ (k8s-apps/infrastructure/loki) に移管済み。
*/
v: {
  monitoring = {
    # Node Exporter設定
    nodeExporter = {
      port = v.assertPort "monitoring.nodeExporter.port" 9100;
    };

    # Grafana設定 (k3s 上の外部 URL のみ保持、本体は k3s クラスタでホスト)
    grafana = {
      domain = v.assertString "monitoring.grafana.domain" "grafana.shinbunbun.com";
    };

    # Alertmanager設定 (k3s 上の VMAlertmanager を LAN VIP 経由で参照、Loki ruler が使用)
    alertmanager = {
      port = v.assertPort "monitoring.alertmanager.port" 9093;
      vip = v.assertString "monitoring.alertmanager.vip" "192.168.128.13";
    };

    # Loki設定 (Fluent Bit クライアント参照用のみ、本体は k3s クラスタ)
    loki = {
      # k3s 上の loki-lan Service (Cilium LB IPAM 固定 VIP)
      host = v.assertString "monitoring.loki.host" "192.168.128.14";
      port = v.assertPort "monitoring.loki.port" 3100;
    };
  };
}

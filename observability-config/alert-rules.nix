# Prometheus Alert Rules
#
# このファイルはPrometheusのアラートルールを定義します。
# nixos-observability モジュールに渡されます。

[
  {
    name = "system";
    interval = "30s";
    rules = [
      # インスタンスダウン
      {
        alert = "InstanceDown";
        expr = "up == 0";
        for = "2m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Instance {{ $labels.instance }} down";
          description = "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 2 minutes.";
        };
      }
      # 高CPU使用率
      {
        alert = "HighCPUUsage";
        expr = "(1 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) by (instance)) * 100 > 80";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High CPU usage on {{ $labels.instance }}";
          description = "CPU usage is above 80% (current value: {{ $value }}%)";
        };
      }
      # 高メモリ使用率
      {
        alert = "HighMemoryUsage";
        expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High memory usage on {{ $labels.instance }}";
          description = "Memory usage is above 85% (current value: {{ $value }}%)";
        };
      }
      # メモリ不足クリティカル
      {
        alert = "CriticalMemoryUsage";
        expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90";
        for = "2m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Critical memory usage on {{ $labels.instance }}";
          description = "Memory usage is above 90% (current value: {{ $value }}%). System may become unstable.";
        };
      }
      # ディスク容量不足
      {
        alert = "DiskSpaceLow";
        expr = "(node_filesystem_size_bytes{fstype!~\"tmpfs|fuse.lxcfs\"} - node_filesystem_free_bytes{fstype!~\"tmpfs|fuse.lxcfs\"}) / node_filesystem_size_bytes{fstype!~\"tmpfs|fuse.lxcfs\"} * 100 > 85";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Low disk space on {{ $labels.instance }}";
          description = "Disk usage is above 85% on {{ $labels.mountpoint }} (current value: {{ $value }}%)";
        };
      }
      # Swap使用量警告
      {
        alert = "HighSwapUsage";
        expr = "(1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100 > 50";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High swap usage on {{ $labels.instance }}";
          description = "Swap usage is above 50% (current value: {{ $value }}%). This may indicate memory pressure.";
        };
      }
      # RouterOS高温度
      {
        alert = "RouterOSHighTemperature";
        expr = "mtxrHlTemperature / 10 > 60";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High temperature on RouterOS";
          description = "RouterOS temperature is above 60°C (current value: {{ $value }}°C)";
        };
      }
      # CPUスロットリング検知
      {
        alert = "RouterOSCPUThrottling";
        expr = "mtxrHlCpuFrequency < 600 and mtxrHlTemperature / 10 > 50";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "CPU throttling detected on RouterOS";
          description = "CPU frequency dropped to {{ $value }}MHz while temperature is high. This may indicate thermal throttling.";
        };
      }
      # RouterOS CPU高使用率
      {
        alert = "RouterOSHighCPU";
        expr = "avg(hrProcessorLoad) > 80";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High CPU usage on RouterOS";
          description = "RouterOS CPU usage is above 80% (current value: {{ $value }}%)";
        };
      }
      # RouterOS再起動検知
      {
        alert = "RouterOSRestarted";
        expr = "increase(mtxrSystemRebootCount[1h]) > 0";
        for = "1m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "RouterOS has been restarted";
          description = "RouterOS device has been restarted (reboot count increased by {{ $value }})";
        };
      }
      # RouterOS不良ブロック検出
      {
        alert = "RouterOSBadBlocks";
        expr = "mtxrSystemBadBlocks > 0";
        for = "5m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Bad blocks detected on RouterOS";
          description = "RouterOS has detected {{ $value }} bad blocks in memory";
        };
      }
      # RouterOSアップデート通知
      # 注: RouterOSのバージョン文字列比較はPromQLでは直接サポートされないため、
      # 手動チェックまたは外部スクリプトで実装することを推奨
      # RouterOS USB電源問題
      {
        alert = "RouterOSUSBPowerIssue";
        expr = "increase(mtxrSystemUSBPowerResets[24h]) > 0";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "USB power resets detected on RouterOS";
          description = "RouterOS USB power has been reset {{ $value }} times in the last 24 hours";
        };
      }
      # DHCP枯渇警告
      {
        alert = "DHCPPoolNearExhaustion";
        expr = "mtxrDHCPLeaseCount > 200"; # 約80% of typical 250 address pool
        for = "10m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "DHCP pool near exhaustion";
          description = "Active DHCP leases ({{ $value }}) approaching pool limit (80% threshold)";
        };
      }
      # インターフェースエラー率
      {
        alert = "RouterOSHighErrorRate";
        expr = "rate(ifInErrors{job=\"routeros\"}[5m]) > 100";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High interface error rate on RouterOS";
          description = "Interface {{ $labels.ifDescr }} experiencing high error rate ({{ $value }} errors/sec)";
        };
      }
      # パケットドロップ率
      {
        alert = "RouterOSHighPacketDropRate";
        expr = "rate(mtxrInterfaceRxDrop{job=\"routeros\"}[5m]) > 1000 or rate(mtxrInterfaceTxDrop{job=\"routeros\"}[5m]) > 1000";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High packet drop rate on RouterOS interface";
          description = "Interface {{ $labels.mtxrInterfaceName }} is dropping packets at {{ $value }} packets/sec";
        };
      }
      # インターフェース帯域使用率
      {
        alert = "RouterOSHighBandwidthUsage";
        expr = "(rate(ifInOctets{job=\"routeros\"}[5m]) * 8 / ifSpeed{job=\"routeros\"}) > 0.8 or (rate(ifOutOctets{job=\"routeros\"}[5m]) * 8 / ifSpeed{job=\"routeros\"}) > 0.8";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High bandwidth usage on RouterOS interface";
          description = "Interface {{ $labels.ifDescr }} is using more than 80% of its bandwidth ({{ $value | humanizePercentage }})";
        };
      }
      # ネットワークインターフェースダウン
      {
        alert = "NetworkInterfaceDown";
        expr = "node_network_up{device!~\"lo|docker.*|veth.*|br.*|tap.*|tun.*|wlp[0-9]s0|wg.*|enp4s0|enp6s0f1\"} == 0";
        for = "2m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Network interface {{ $labels.device }} down on {{ $labels.instance }}";
          description = "Network interface {{ $labels.device }} has been down for more than 2 minutes.";
        };
      }
      # 高ネットワークトラフィック（受信）
      {
        alert = "HighNetworkTrafficIn";
        expr = "rate(node_network_receive_bytes_total[5m]) > 100000000"; # 100MB/s
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High network traffic (inbound) on {{ $labels.instance }}";
          description = "Network interface {{ $labels.device }} is receiving more than 100MB/s (current: {{ $value | humanize }}B/s)";
        };
      }
      # 高ネットワークトラフィック（送信）
      {
        alert = "HighNetworkTrafficOut";
        expr = "rate(node_network_transmit_bytes_total[5m]) > 100000000"; # 100MB/s
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High network traffic (outbound) on {{ $labels.instance }}";
          description = "Network interface {{ $labels.device }} is transmitting more than 100MB/s (current: {{ $value | humanize }}B/s)";
        };
      }
      # パケットロス率（受信エラー）
      {
        alert = "HighPacketLossReceive";
        expr = "rate(node_network_receive_errs_total[5m]) > 0.01";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High packet receive errors on {{ $labels.instance }}";
          description = "Network interface {{ $labels.device }} is experiencing receive errors ({{ $value }} errors/sec)";
        };
      }
      # systemdサービス停止
      {
        alert = "SystemdServiceFailed";
        expr = "node_systemd_unit_state{state=\"failed\"} == 1";
        for = "2m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Systemd service {{ $labels.name }} failed on {{ $labels.instance }}";
          description = "The systemd service {{ $labels.name }} is in failed state.";
        };
      }
      # サービス再起動頻度（NetworkManager-dispatcherを除外）
      {
        alert = "SystemdServiceFlapping";
        expr = "changes(node_systemd_unit_state{state=\"active\",name!=\"NetworkManager-dispatcher.service\"}[15m]) > 3";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Systemd service {{ $labels.name }} is flapping on {{ $labels.instance }}";
          description = "The systemd service {{ $labels.name }} has restarted more than 3 times in the last 15 minutes.";
        };
      }
      # 高ディスクI/O使用率
      {
        alert = "HighDiskIOUtilization";
        expr = "rate(node_disk_io_time_seconds_total[5m]) > 0.9";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High disk I/O utilization on {{ $labels.instance }}";
          description = "Disk {{ $labels.device }} I/O utilization is above 90% (current value: {{ $value | humanizePercentage }})";
        };
      }
      # システムロード
      {
        alert = "HighSystemLoad";
        expr = "node_load5 / count(node_cpu_seconds_total{mode=\"idle\"}) by (instance) > 2";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High system load on {{ $labels.instance }}";
          description = "System load average (5m) is high relative to CPU count (current value: {{ $value }})";
        };
      }
      # inode使用率
      {
        alert = "HighInodeUsage";
        expr = "(1 - (node_filesystem_files_free{fstype!~\"tmpfs|fuse.lxcfs\"} / node_filesystem_files{fstype!~\"tmpfs|fuse.lxcfs\"})) * 100 > 85";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High inode usage on {{ $labels.instance }}";
          description = "Inode usage is above 85% on {{ $labels.mountpoint }} (current value: {{ $value }}%)";
        };
      }
      # 時刻同期ずれ
      {
        alert = "ClockSkewDetected";
        expr = "abs(node_timex_offset_seconds) > 10";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Clock skew detected on {{ $labels.instance }}";
          description = "System clock is {{ $value }} seconds off from NTP time. This may cause issues with time-sensitive operations.";
        };
      }
      # NTP同期失敗
      {
        alert = "NTPSyncFailed";
        expr = "node_timex_sync_status == 0";
        for = "10m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "NTP synchronization failed on {{ $labels.instance }}";
          description = "System is not synchronized with NTP servers for more than 10 minutes.";
        };
      }
      # RouterOSバックアップ失敗（homeMachineのみ）
      {
        alert = "RouterOSBackupFailed";
        expr = "node_systemd_unit_state{name=\"routeros-backup.service\",state=\"failed\",instance=\"nixos.shinbunbun.com\"} == 1";
        for = "5m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "RouterOS backup service failed on {{ $labels.instance }}";
          description = "RouterOS backup service has been in failed state for more than 5 minutes. Check logs: journalctl -u routeros-backup.service";
        };
      }
      # RouterOSバックアップ長時間未実行（homeMachineのみ）
      {
        alert = "RouterOSBackupStale";
        expr = "time() - node_systemd_timer_last_trigger_seconds{name=\"routeros-backup.timer\",instance=\"nixos.shinbunbun.com\"} > 90000";
        for = "1h";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "RouterOS backup has not run for more than 25 hours";
          description = "RouterOS backup timer has not triggered for {{ $value | humanizeDuration }}.";
        };
      }
    ];
  }
  # RouterOS専用グループ
  {
    name = "routeros";
    interval = "30s";
    rules = [
      # RouterOSインターフェースダウン（重要なインターフェースのみ）
      {
        alert = "RouterOSInterfaceDown";
        expr = "ifOperStatus{job=\"routeros\",ifIndex!~\"2|4|5|7|8\"} == 2";
        for = "2m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "RouterOS interface (ifIndex={{ $labels.ifIndex }}) is down";
          description = "Interface (ifIndex={{ $labels.ifIndex }}) on RouterOS has been down for more than 2 minutes.";
        };
      }
      # RouterOSインターフェースエラー率
      {
        alert = "RouterOSInterfaceErrors";
        expr = "(rate(ifInErrors{job=\"routeros\",ifIndex!~\"9|12\"}[5m]) > 0.01 or rate(ifOutErrors{job=\"routeros\",ifIndex!~\"9|12\"}[5m]) > 0.01) or (rate(ifInErrors{job=\"routeros\",ifIndex=\"12\"}[5m]) > 0.1 or rate(ifOutErrors{job=\"routeros\",ifIndex=\"12\"}[5m]) > 0.1)";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High error rate on RouterOS interface ifIndex={{ $labels.ifIndex }}";
          description = "Interface ifIndex={{ $labels.ifIndex }} is experiencing high error rates ({{ $value }} errors/sec).";
        };
      }
      # RouterOSメモリ使用率
      {
        alert = "RouterOSHighMemoryUsage";
        expr = "(hrStorageUsed{job=\"routeros\",hrStorageIndex=\"65536\"} / hrStorageSize{job=\"routeros\",hrStorageIndex=\"65536\"}) * 100 > 85";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High memory usage on RouterOS";
          description = "RouterOS memory usage is above 85% (free: {{ $value }}%)";
        };
      }
      # RouterOS WireGuardインターフェース監視
      {
        alert = "RouterOSWireGuardDown";
        expr = "ifOperStatus{job=\"routeros\",ifIndex=\"12\"} == 2";
        for = "2m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "WireGuard interface is down";
          description = "WireGuard interface (wg-home) has been down for more than 2 minutes.";
        };
      }
      # WireGuardトラフィック停止検知
      {
        alert = "RouterOSWireGuardNoTraffic";
        expr = "rate(ifInOctets{job=\"routeros\",ifIndex=\"12\"}[10m]) == 0 and rate(ifOutOctets{job=\"routeros\",ifIndex=\"12\"}[10m]) == 0";
        for = "10m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "No WireGuard traffic detected";
          description = "No traffic has been detected on WireGuard interface (wg-home) for more than 10 minutes.";
        };
      }
      # PPPoE接続ダウン
      {
        alert = "RouterOSPPPoEDown";
        expr = "ifOperStatus{job=\"routeros\",ifIndex=\"10\"} == 2";
        for = "2m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "PPPoE connection is down";
          description = "PPPoE connection (pppoe-out1) has been down for more than 2 minutes.";
        };
      }
    ];
  }
  # ディスクヘルスグループ
  {
    name = "disk-health";
    interval = "30s";
    rules = [
      # ディスクエラー検知（SMART）
      {
        alert = "DiskSMARTErrors";
        expr = "node_disk_read_errors_total > 0 or node_disk_write_errors_total > 0";
        for = "5m";
        labels = {
          severity = "critical";
        };
        annotations = {
          summary = "Disk errors detected on {{ $labels.instance }}";
          description = "Disk {{ $labels.device }} is reporting read/write errors. Check disk health immediately.";
        };
      }
    ];
  }
  # ログベースのアラートグループ（メトリクスベース）
  # 注: LogQLクエリはLokiのルーラーで実行する必要があるため、
  # ここではPromtailが公開するメトリクスを使用
  {
    name = "logs";
    interval = "30s";
    rules = [
      # Promtailのログ取り込み遅延
      {
        alert = "LogIngestionLag";
        expr = "(time() - max(promtail_stream_lag_seconds)) > 60";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Log ingestion lag detected";
          description = "Promtail is {{ $value }} seconds behind in processing logs";
        };
      }
      # Promtailのログドロップ検知
      {
        alert = "PromtailDroppedLogs";
        expr = "rate(promtail_dropped_entries_total[5m]) > 0";
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Promtail is dropping logs";
          description = "Promtail dropped {{ $value }} logs/sec in the last 5 minutes";
        };
      }
      # Lokiのインジェスト失敗
      {
        alert = "LokiIngestionErrors";
        expr = ''rate(loki_ingester_chunks_flushed_total{success="false"}[5m]) > 0'';
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "Loki ingestion errors detected";
          description = "Loki failed to flush {{ $value }} chunks/sec";
        };
      }
      # Lokiクエリ遅延
      {
        alert = "LokiQueryLatency";
        expr = ''histogram_quantile(0.95, rate(loki_request_duration_seconds_bucket{route=~"loki_api_v1_query|loki_api_v1_query_range"}[5m])) > 10'';
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High Loki query latency";
          description = "95th percentile query latency is {{ $value }} seconds";
        };
      }
    ];
  }
]

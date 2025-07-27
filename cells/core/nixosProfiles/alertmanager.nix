# cells/core/nixosProfiles/alertmanager.nix
/*
  Alertmanager設定モジュール

  このモジュールはPrometheusのアラート管理と
  Discord通知を設定します：
  - Alertmanager: アラートのルーティングと通知
  - Discord Webhook: アラート通知の送信先
  - アラートルール: 監視対象の異常を検知

  アラートはグループ化され、重複排除された後
  Discordチャンネルに送信されます。
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
  # Alertmanager設定
  services.prometheus.alertmanager = {
    enable = true;
    port = cfg.monitoring.alertmanager.port;
    checkConfig = false; # 環境変数を使うため、ビルド時検証を無効化

    # configTextではなくconfigurationを使い、環境変数を使用
    configuration = {
      global = {
        resolve_timeout = "5m";
      };

      route = {
        receiver = "discord";
        group_by = [
          "alertname"
          "cluster"
          "service"
        ];
        group_wait = "10s";
        group_interval = "10s";
        repeat_interval = "1h";
        routes = [
          {
            match = {
              severity = "critical";
            };
            receiver = "discord";
            repeat_interval = "15m";
          }
          {
            match = {
              severity = "warning";
            };
            receiver = "discord";
            repeat_interval = "30m";
          }
        ];
      };

      receivers = [
        {
          name = "discord";
          discord_configs = [
            {
              webhook_url = "$DISCORD_WEBHOOK_URL";
              send_resolved = true;
            }
          ];
        }
      ];

      inhibit_rules = [
        {
          source_match = {
            severity = "critical";
          };
          target_match = {
            severity = "warning";
          };
          equal = [
            "alertname"
            "instance"
          ];
        }
      ];
    };

    # 環境変数ファイルを指定
    environmentFile = "/run/secrets/rendered/alertmanager/env";
  };

  # Prometheus側のAlertmanager連携設定
  services.prometheus.alertmanagers = [
    {
      static_configs = [
        {
          targets = [ "localhost:${toString cfg.monitoring.alertmanager.port}" ];
        }
      ];
    }
  ];

  # アラートルールの設定
  services.prometheus.rules = [
    (builtins.toJSON {
      groups = [
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
            # ネットワークインターフェースダウン
            {
              alert = "NetworkInterfaceDown";
              expr = "node_network_up{device!~\"lo|docker.*|veth.*|br.*|tap.*|tun.*|wlp1s0\"} == 0";
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
            # サービス再起動頻度
            {
              alert = "SystemdServiceFlapping";
              expr = "changes(node_systemd_unit_state{state=\"active\"}[15m]) > 3";
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
          ];
        }
        # RouterOS専用グループ
        {
          name = "routeros";
          interval = "30s";
          rules = [
            # RouterOSインターフェースダウン
            {
              alert = "RouterOSInterfaceDown";
              expr = "ifOperStatus{job=\"routeros\"} == 2";
              for = "2m";
              labels = {
                severity = "critical";
              };
              annotations = {
                summary = "RouterOS interface {{ $labels.ifDescr }} is down";
                description = "Interface {{ $labels.ifDescr }} on RouterOS has been down for more than 2 minutes.";
              };
            }
            # RouterOSインターフェースエラー率
            {
              alert = "RouterOSInterfaceErrors";
              expr = "rate(ifInErrors{job=\"routeros\"}[5m]) > 0.01 or rate(ifOutErrors{job=\"routeros\"}[5m]) > 0.01";
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "High error rate on RouterOS interface {{ $labels.ifDescr }}";
                description = "Interface {{ $labels.ifDescr }} is experiencing high error rates.";
              };
            }
            # RouterOSメモリ使用率
            {
              alert = "RouterOSHighMemoryUsage";
              expr = "(hrStorageUsed{hrStorageDescr=\"main memory\"} / hrStorageSize{hrStorageDescr=\"main memory\"}) * 100 > 85";
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "High memory usage on RouterOS";
                description = "RouterOS memory usage is above 85% (free: {{ $value }}%)";
              };
            }
            # RouterOS WireGuardピア接続状態監視
            {
              alert = "RouterOSWireGuardPeerDown";
              expr = "mtxrWgPeerLastHandshake{job=\"routeros\"} > 180";
              for = "5m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "WireGuard peer {{ $labels.mtxrWgPeerAddr }} is down";
                description = "WireGuard peer {{ $labels.mtxrWgPeerAddr }} on interface {{ $labels.mtxrWgPeerIface }} has not had a handshake for {{ $value }} seconds.";
              };
            }
            # PPPoE接続ダウン
            {
              alert = "RouterOSPPPoEDown";
              expr = "ifOperStatus{job=\"routeros\",ifDescr=\"pppoe-out1\"} == 2";
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
      ];
    })
  ];

  # SOPS secrets設定
  sops = {
    # Discord Webhook URLの秘密鍵
    secrets."alertmanager/discord_webhook_url" = {
      key = "discord/webhook_url";
      sopsFile = "${inputs.self}/secrets/alertmanager.yaml";
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };

    # Discord ユーザーIDの秘密鍵
    secrets."alertmanager/discord_user_id" = {
      key = "discord/user_id";
      sopsFile = "${inputs.self}/secrets/alertmanager.yaml";
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };

    # 環境変数テンプレート
    templates."alertmanager/env" = {
      content = ''
        DISCORD_WEBHOOK_URL=${config.sops.placeholder."alertmanager/discord_webhook_url"}
        DISCORD_USER_ID=${config.sops.placeholder."alertmanager/discord_user_id"}
      '';
      path = "/run/secrets/rendered/alertmanager/env";
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };

    # Alertmanager設定テンプレート（今は使わないがあとで使うかもしれないので残す）
    templates."alertmanager/config.yml" = {
      content = ''
        global:
          resolve_timeout: 5m

        route:
          receiver: discord
          group_by: ['alertname', 'cluster', 'service']
          group_wait: 10s
          group_interval: 10s
          repeat_interval: 1h
          routes:
          - match:
              severity: critical
            receiver: discord
            repeat_interval: 15m
          - match:
              severity: warning
            receiver: discord
            repeat_interval: 30m

        receivers:
        - name: discord
          discord_configs:
          - webhook_url: ${config.sops.placeholder."alertmanager/discord_webhook_url"}
            send_resolved: true

        inhibit_rules:
        - source_match:
            severity: critical
          target_match:
            severity: warning
          equal: ['alertname', 'instance']
      '';
      path = "/run/secrets/rendered/alertmanager/config.yml";
      owner = "prometheus";
      group = "prometheus";
      mode = "0400";
    };
  };

  # ファイアウォール設定（内部アクセスのみ）
  networking.firewall.allowedTCPPorts = [ cfg.monitoring.alertmanager.port ];

  # systemdサービスの依存関係
  systemd.services.alertmanager = {
    after = [ "prometheus.service" ];
    wants = [ "prometheus.service" ];
  };
}

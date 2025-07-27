# Alertmanager設定手順

## 概要
PrometheusのアラートをDiscordに通知するためのAlertmanager設定手順です。

## 前提条件
- Prometheus、Grafanaが設定済み
- Discord Webhookが作成済み

## 設定手順

### 1. Discord Webhook URLの設定

1. Discord Webhookを作成（Discordサーバー設定から作成）
2. `secrets/alertmanager.yaml`にWebhook URLを設定：
   ```yaml
   discord:
       webhook_url: "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
   ```

3. SOPSで暗号化：
   ```bash
   sops -e -i secrets/alertmanager.yaml
   ```

### 2. NixOS設定の適用

```bash
sudo nixos-rebuild switch --flake .#homeMachine
```

### 3. 動作確認

1. Alertmanagerのステータス確認：
   ```bash
   systemctl status alertmanager
   ```

2. Prometheusのアラート確認：
   ```bash
   curl http://localhost:9090/api/v1/alerts
   ```

3. Alertmanagerのアラート確認：
   ```bash
   curl http://localhost:9093/api/v1/alerts
   ```

## アラートルール

以下のアラートが設定されています：

- **InstanceDown**: インスタンスが2分以上ダウン（critical）
- **HighCPUUsage**: CPU使用率が80%以上（warning）
- **HighMemoryUsage**: メモリ使用率が85%以上（warning）
- **DiskSpaceLow**: ディスク使用率が85%以上（warning）
- **RouterOSHighTemperature**: RouterOSの温度が60°C以上（warning）
- **RouterOSHighCPU**: RouterOSのCPU使用率が80%以上（warning）

## トラブルシューティング

### アラートが送信されない場合

1. Alertmanagerのログを確認：
   ```bash
   journalctl -u alertmanager -f
   ```

2. Discord Webhook URLが正しいか確認
3. SOPSの復号化が正しく行われているか確認

### テストアラートの送信

```bash
curl -XPOST http://localhost:9093/api/v1/alerts -H "Content-Type: application/json" -d '[
  {
    "status": "firing",
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "test"
    },
    "annotations": {
      "summary": "This is a test alert",
      "description": "Testing Discord webhook integration"
    }
  }
]'
```
# RouterOS アラート動作確認手順

## 概要
新しく追加したRouterOS監視アラートの動作確認手順を記載します。

## 追加したアラートルール

### 1. RouterOS再起動検知
- **アラート名**: RouterOSRestarted
- **条件**: 再起動回数が1時間以内に増加
- **重要度**: warning
- **通知内容**: デバイスが再起動したことを通知

### 2. RouterOS不良ブロック検出
- **アラート名**: RouterOSBadBlocks
- **条件**: 不良ブロックが1個以上検出
- **重要度**: critical
- **通知内容**: メモリ内の不良ブロック数

### 3. RouterOS USB電源問題
- **アラート名**: RouterOSUSBPowerIssue
- **条件**: USB電源リセットが24時間以内に発生
- **重要度**: warning
- **通知内容**: USB電源リセット回数

### 4. DHCP枯渇警告
- **アラート名**: DHCPPoolNearExhaustion
- **条件**: アクティブリース数が200を超過
- **重要度**: warning
- **通知内容**: DHCPプールの枯渇が近いことを警告

### 5. インターフェースエラー率
- **アラート名**: RouterOSHighErrorRate
- **条件**: エラー率が100エラー/秒を超過
- **重要度**: warning
- **通知内容**: 高エラー率のインターフェース名

## 動作確認手順

### 1. 設定の適用
```bash
# NixOS設定を再構築して適用
sudo nixos-rebuild switch --flake .#toplevel-homeMachine

# Prometheusサービスの再起動
sudo systemctl restart prometheus.service

# Alertmanagerサービスの再起動
sudo systemctl restart alertmanager.service
```

### 2. アラートルールの確認

#### Prometheus Web UIでの確認
1. Prometheus UIにアクセス: http://localhost:9090
2. 「Alerts」タブを開く
3. 新しいアラートルールが表示されることを確認

#### アラートルールの状態確認
```bash
# アクティブなアラートを確認
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname | startswith("RouterOS"))'
```

### 3. 個別アラートのテスト

#### RouterOSRestarted（再起動検知）のテスト
```bash
# 注意: 実際にRouterOSを再起動する必要があります
# RouterOSにSSH接続して実行
/system reboot

# 再起動後、アラートが発火することを確認
```

#### DHCPPoolNearExhaustion（DHCP枯渇）のテスト
```bash
# 現在のDHCPリース数を確認
curl -s "http://localhost:9116/snmp?target=192.168.1.1&module=mikrotik" | grep mtxrDHCPLeaseCount

# テスト用に閾値を現在値に近い値に一時的に変更して確認
```

#### RouterOSHighErrorRate（エラー率）のテスト
```bash
# 現在のエラー率を確認
curl -s http://localhost:9090/api/v1/query?query='rate(ifInErrors{job="routeros"}[5m])' | jq
```

### 4. Alertmanagerでの確認

#### Alertmanager UIアクセス
1. Alertmanager UIにアクセス: http://localhost:9093
2. 発火したアラートが表示されることを確認

#### コマンドラインでの確認
```bash
# アクティブなアラートを確認
curl -s http://localhost:9093/api/v1/alerts | jq '.[] | select(.labels.alertname | startswith("RouterOS"))'
```

### 5. Discord通知の確認
1. 設定されたDiscordチャンネルを確認
2. アラートが発火した際に通知が届くことを確認

通知形式の例：
```
🚨 **Alert: RouterOSRestarted**
**Summary:** RouterOS has been restarted
**Description:** RouterOS device has been restarted (reboot count increased by 1)
**Severity:** warning
**Instance:** 192.168.1.1
```

## トラブルシューティング

### アラートが発火しない場合
1. Prometheusのログを確認
   ```bash
   journalctl -u prometheus -f
   ```

2. メトリクスが正しく収集されているか確認
   ```bash
   curl -s http://localhost:9090/api/v1/query?query='mtxrSystemRebootCount' | jq
   ```

3. アラートルールの評価状態を確認
   ```bash
   curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.name | startswith("RouterOS"))'
   ```

### Discord通知が届かない場合
1. Alertmanagerのログを確認
   ```bash
   journalctl -u alertmanager -f
   ```

2. Webhook URLが正しく設定されているか確認
   ```bash
   sudo cat /run/secrets/rendered/alertmanager/config.yml | grep webhook_url
   ```

## アラート閾値の調整

各アラートの閾値は用途に応じて調整が必要です：

| アラート名 | 現在の閾値 | 推奨調整 |
|-----------|------------|----------|
| DHCPPoolNearExhaustion | 200リース | DHCPプールサイズの80%程度に設定 |
| RouterOSHighErrorRate | 100エラー/秒 | ネットワーク規模に応じて調整 |
| RouterOSHighTemperature | 60°C | デバイスの仕様に応じて調整 |

## 関連ファイル
- アラート設定: `/home/bunbun/dotfiles/cells/core/nixosProfiles/alertmanager.nix`
- SNMP設定: `/home/bunbun/dotfiles/cells/core/nixosProfiles/snmp.yml`
- 監視設定: `/home/bunbun/dotfiles/cells/core/nixosProfiles/monitoring.nix`
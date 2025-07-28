# 監視システム実装計画

## 概要

NixOSサーバーとRouterOSデバイスの監視システムを構築する計画書です。

## 要件

### 機能要件
- **監視対象**: NixOSサーバー（nixos.shinbunbun.com）、RouterOSデバイス（192.168.1.1）
- **データ保存期間**: 30日
- **外部アクセス**: Cloudflare Tunnel経由で提供
- **アラート通知**: Discord
- **コスト**: 無料（セルフホスト）

### 非機能要件
- Nixによる構成管理
- 低リソース消費
- 高可用性

## アーキテクチャ

### 技術スタック
- **メトリクス収集**: Prometheus
- **可視化**: Grafana
- **アラート**: Alertmanager + Discord Webhook
- **エクスポーター**: Node Exporter, SNMP Exporter
- **外部公開**: Cloudflare Tunnel

### システム構成図

```
┌─────────────────┐     ┌──────────────────┐
│   NixOSサーバー  │     │    RouterOS      │
│                 │     │  (192.168.1.1)   │
│ ┌─────────────┐ │     │                  │
│ │Node Exporter│ │     │  SNMP有効化      │
│ └──────┬──────┘ │     └────────┬─────────┘
│        │        │              │
│ ┌──────▼────────────────────┐ │
│ │      Prometheus           │ │
│ │  - Node Exporter収集      │ │
│ │  - SNMP Exporter収集      │ │
│ └──────┬────────────────────┘ │
│        │                      │
│ ┌──────▼────────┐  ┌─────────┐│
│ │    Grafana    │  │Alertmgr ││
│ │ ダッシュボード │  │Discord  ││
│ └───────────────┘  │Webhook  ││
│                    └─────────┘│
└─────────────────────────────┘
         │
         ▼
   Cloudflare Tunnel
   (監視UI外部公開)
```

## 実装状況

### ✅ 完了したフェーズ

#### Phase 1: 基本監視システム構築 [完了]
- Prometheusのセットアップ完了
- Node Exporterの設定完了
- Grafanaのセットアップとダッシュボード作成完了
- Cloudflare Tunnel経由での外部公開完了

#### Phase 2: RouterOS監視追加 [完了]
- RouterOS側のSNMP設定完了
- SNMP Exporterの設定と統合完了
- RouterOSダッシュボード作成完了

#### Phase 3: アラート設定 [完了]
- Alertmanagerの設定完了
- Discord Webhook統合完了
- 包括的なアラートルール作成完了

### 🆕 追加実装（2025年7月）

#### 時刻同期監視
- systemd-timesyncdによるNTP設定
- 時刻ずれとNTP同期状態の監視
- Grafanaダッシュボードへのパネル追加

#### バックアップ監視
- RouterOSバックアップサービスの監視
- タイマーのランダム遅延を考慮した閾値設定
- バックアップ状態の可視化

#### ログ監視
- ディスク使用量の急激な増加検知
- journalログサイズの管理

## 実装フェーズ

### Phase 1: 基本監視システム構築

#### 1.1 Prometheusのセットアップ
- Prometheusサービスの有効化
- Node Exporterの設定
- 基本的なスクレイプ設定
- データ保持期間の設定（30日）

#### 1.2 Grafanaのセットアップ
- Grafanaサービスの有効化
- Prometheusデータソースの設定
- 基本ダッシュボードの作成
- 認証設定

#### 1.3 外部アクセスの設定
- Cloudflare Tunnelの設定
- grafana.shinbunbun.comでの公開
- HTTPS化

### Phase 2: RouterOS監視追加

#### 2.1 RouterOS側の設定
- SNMP v2cの有効化
- コミュニティ文字列の設定
- アクセス制限の設定

#### 2.2 SNMP Exporterの設定
- SNMP Exporterのインストール
- MikroTik用MIBの設定
- Prometheusへの統合

#### 2.3 RouterOSダッシュボード
- インターフェース監視
- システムリソース監視
- VPNトンネル監視

### Phase 3: アラート設定

#### 3.1 Alertmanagerの設定
- Alertmanagerサービスの有効化
- ルーティング設定
- Discord Webhook設定

#### 3.2 アラートルールの作成
- Critical: サービスダウン、ディスク容量逼迫
- Warning: 高CPU/メモリ使用率
- Info: SSH失敗、バックアップ失敗

#### 3.3 Discord通知の設定
- Webhook URLの設定
- 通知テンプレートの作成
- テスト通知の送信

## 監視項目（実装済み）

### NixOSサーバー

#### システムメトリクス
- ✅ CPU使用率、負荷平均
- ✅ メモリ使用率、スワップ使用率
- ✅ ディスク使用率、I/O統計
- ✅ ネットワークインターフェース統計
- ✅ システムアップタイム
- ✅ 時刻同期状態（NTP）
- ✅ inode使用率

#### サービス監視
- ✅ Dockerデーモン状態（Systemdサービス監視）
- ✅ SSH サービス状態
- ✅ WireGuard VPN接続状態
- ✅ Fail2ban状態（Systemdサービス監視）
- ✅ RouterOSバックアップサービス状態

#### ログ監視
- ✅ ディスク使用量の急激な増加（ログ起因の可能性）
- ⚠️ SSH認証失敗（Fail2banが対処）

### RouterOS

#### システムメトリクス
- ✅ CPU使用率
- ✅ メモリ使用率
- ✅ システム温度
- ✅ アップタイム

#### ネットワーク監視
- ✅ インターフェース別トラフィック（入出力）
- ✅ インターフェース状態（UP/DOWN）
- ✅ パケットエラー率（WireGuard用に閾値調整済み）
- ✅ WireGuard VPNトンネル状態
- ✅ PPPoE接続状態

#### セキュリティ監視
- ❌ ファイアウォールログ（OID未サポート - MikroTik公式確認済み）
- ❌ 接続数統計（OID未サポート - MikroTik公式確認済み）
  - 注: SNMPスクリプト実行機能を使用した回避策は存在するが、
    セキュリティ上の理由（SNMP書き込み権限が必要）により実装見送り

## アラートルール

### Critical（即時通知）
```yaml
- alert: InstanceDown
  expr: up == 0
  for: 5m
  annotations:
    summary: "サーバーダウン: {{ $labels.instance }}"

- alert: DiskSpaceCritical
  expr: disk_free_percent < 10
  for: 5m
  annotations:
    summary: "ディスク容量逼迫: {{ $value }}% 空き"

- alert: CouchDBDown
  expr: container_state_running{name="couchdb"} == 0
  for: 1m
  annotations:
    summary: "CouchDBコンテナ停止"
```

### Warning（15分後通知）
```yaml
- alert: HighCPUUsage
  expr: cpu_usage_percent > 80
  for: 15m
  annotations:
    summary: "高CPU使用率: {{ $value }}%"

- alert: HighMemoryUsage
  expr: memory_usage_percent > 85
  for: 15m
  annotations:
    summary: "高メモリ使用率: {{ $value }}%"

- alert: WireGuardDown
  expr: wireguard_peer_last_handshake_seconds > 300
  for: 5m
  annotations:
    summary: "WireGuard接続断"
```

### Info（30分後通知）
```yaml
- alert: SSHAuthFailure
  expr: rate(ssh_auth_failures[5m]) > 5
  for: 30m
  annotations:
    summary: "SSH認証失敗多発: {{ $value }}/分"

- alert: BackupFailed
  expr: routeros_backup_last_success > 86400
  for: 30m
  annotations:
    summary: "RouterOSバックアップ失敗"
```

## Discord通知フォーマット

### Critical通知
```
🚨 **[CRITICAL]** {{ .GroupLabels.alertname }}
📍 **ホスト**: {{ .Labels.instance }}
⏰ **発生時刻**: {{ .StartsAt.Format "2006-01-02 15:04:05" }}
📊 **詳細**: {{ .Annotations.summary }}
🔗 **ダッシュボード**: https://grafana.shinbunbun.com
```

### Warning通知
```
⚠️ **[WARNING]** {{ .GroupLabels.alertname }}
📍 **ホスト**: {{ .Labels.instance }}
⏰ **発生時刻**: {{ .StartsAt.Format "2006-01-02 15:04:05" }}
📊 **詳細**: {{ .Annotations.summary }}
🔗 **ダッシュボード**: https://grafana.shinbunbun.com
```

### 復旧通知
```
✅ **[RESOLVED]** {{ .GroupLabels.alertname }}
📍 **ホスト**: {{ .Labels.instance }}
⏰ **復旧時刻**: {{ .EndsAt.Format "2006-01-02 15:04:05" }}
⏱️ **継続時間**: {{ .Duration }}
```

## セキュリティ考慮事項

1. **認証**
   - Grafana: OAuth2またはLDAP認証
   - Prometheus/Alertmanager: 内部アクセスのみ

2. **ネットワーク**
   - Cloudflare Tunnelによる安全な外部公開
   - SNMP: ローカルネットワーク内のみ

3. **シークレット管理**
   - Discord Webhook URL: SOPSで暗号化
   - SNMP コミュニティ文字列: SOPSで暗号化

## 運用手順

### 日常運用
1. Grafanaダッシュボードの定期確認
2. アラート対応手順の文書化
3. メトリクスの閾値調整

### メンテナンス
1. Prometheusデータベースの定期クリーンアップ
2. Grafanaダッシュボードのバックアップ
3. アラートルールの見直し

## 今後の拡張案

1. **ログ収集**: Loki導入によるログ統合管理
2. **APM**: アプリケーションパフォーマンス監視
3. **合成監視**: 外部からのサービス死活監視
4. **カスタムメトリクス**: アプリケーション固有の監視

## 参考リンク

- [Prometheus公式ドキュメント](https://prometheus.io/docs/)
- [Grafana公式ドキュメント](https://grafana.com/docs/)
- [MikroTik SNMP設定](https://wiki.mikrotik.com/wiki/Manual:SNMP)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [SNMP Exporter](https://github.com/prometheus/snmp_exporter)
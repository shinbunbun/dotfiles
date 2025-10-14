# Grafana × OpenSearch 統合計画

## 📋 概要

本ドキュメントは、OpenSearchログ検索基盤とGrafana監視システムを統合し、統一的なログ可視化・メトリクス監視環境を構築する計画を定義します。

**目的**:
- OpenSearch Dashboards: ログ検索・フィルタリング（GCP Cloud Logging的な使い方）
- Grafana: ログメトリクスの可視化・アラート管理（既存の監視基盤に統合）

## 🎯 ゴール

### Phase 1: OpenSearch Data Source統合（必須）
- [ ] Grafanaに OpenSearch Data Source を追加
- [ ] OpenSearchへの接続確認
- [ ] 基本的なログクエリ動作確認

### Phase 2: ログメトリクスダッシュボード作成（必須）
- [ ] ログ量監視ダッシュボード作成
- [ ] エラーログ監視ダッシュボード作成
- [ ] サービス別ログメトリクスダッシュボード作成
- [ ] 既存のシステムメトリクスダッシュボードと統合

### Phase 3: アラート設定（推奨）
- [ ] エラーログ急増アラート
- [ ] 特定サービスのログ停止アラート
- [ ] ログ量異常検知アラート

### Phase 4: 高度な統合（オプション）
- [ ] Lokiとの統合（ログ集約の二重化）
- [ ] ClickHouseとの連携強化
- [ ] トレース情報との相関

---

## 🏗️ 現状分析

### 既存のGrafana構成

#### Data Sources（現在）
1. **Prometheus** (デフォルト)
   - URL: http://localhost:9090
   - 用途: メトリクス収集・保存
   - スクレイプ対象: Node Exporter, SNMP Exporter

2. **Loki**
   - URL: http://localhost:3100
   - 用途: ログ集約（systemd-journal → Promtail → Loki）
   - 機能: トレースID連携

3. **ClickHouse**
   - URL: http://192.168.1.4:8123
   - 用途: ログ分析・異常検知
   - データベース: logs

#### 既存ダッシュボード
- `overview.json`: 全体監視
- `node.json`: Node Exporterメトリクス
- `nixos-desktop.json`: nixos-desktop専用
- `routeros.json`: RouterOSメトリクス
- `anomaly-wall.json`: 異常検知ダッシュボード

#### 保存場所
```
/home/bunbun/dotfiles/systems/nixos/modules/services/dashboards/
```

---

## 📊 設計: OpenSearch Data Source統合

### 1. Data Source設定

#### NixOS設定追加（monitoring.nix）

```nix
services.grafana.provision.datasources.settings.datasources = [
  # 既存のデータソース...

  # OpenSearch Data Source（新規追加）
  {
    name = "OpenSearch";
    type = "grafana-opensearch-datasource";
    access = "proxy";
    url = "http://localhost:${toString cfg.opensearch.port}";
    database = "logs-*";  # インデックスパターン
    jsonData = {
      timeField = "@timestamp";
      esVersion = "7.10.0";  # OpenSearch互換バージョン
      interval = "Daily";
      logMessageField = "message";
      logLevelField = "level";
    };
    isDefault = false;
  }
];
```

#### プラグインインストール

OpenSearch用のGrafanaプラグインは、Elasticsearchプラグインで代用可能：
- プラグイン名: `grafana-opensearch-datasource` (公式)
- または: `elasticsearch` (互換性あり)

```nix
services.grafana.declarativePlugins = with pkgs.grafanaPlugins; [
  grafana-clickhouse-datasource  # 既存
  # grafana-opensearch-datasource  # 追加予定（nixpkgsで利用可能か要確認）
];
```

**注意**: nixpkgsでOpenSearchプラグインが利用できない場合、Elasticsearchプラグインで代用

---

## 📈 ダッシュボード設計

### Dashboard 1: ログ量監視ダッシュボード

**ファイル名**: `logs-volume-metrics.json`

#### パネル構成

1. **全体ログ量（時系列）**
   - ビジュアライゼーション: Time series
   - クエリ: Count of logs-* grouped by time (1h interval)
   - 目的: ログ量の推移監視

2. **ログレベル別件数（Stat）**
   - ビジュアライゼーション: Stat (複数パネル)
   - クエリ:
     - INFO: `level:6`
     - ERROR: `level:3`
     - WARNING: `level:4`
   - しきい値: ERROR > 100 (赤), > 50 (黄)

3. **サービス別ログ量（Bar Gauge）**
   - ビジュアライゼーション: Bar gauge
   - クエリ: Count grouped by `service.keyword` (Top 10)
   - ソート: Descending

4. **ログ量増減率（Graph）**
   - ビジュアライゼーション: Time series
   - クエリ: Rate of change (derivative)
   - アラート: 急増/急減を検知

#### レイアウト
```
┌─────────────────────────────────────────────┐
│  全体ログ量（時系列）                        │
├──────────┬──────────┬──────────┬───────────┤
│ INFO件数 │ ERROR件数│ WARN件数 │ その他    │
│  (Stat)  │  (Stat)  │  (Stat)  │  (Stat)   │
├──────────────────────┬─────────────────────┤
│ サービス別ログ量     │ ログ量増減率        │
│ (Bar Gauge)          │ (Time series)       │
└──────────────────────┴─────────────────────┘
```

---

### Dashboard 2: エラーログ監視ダッシュボード

**ファイル名**: `logs-errors-monitoring.json`

#### パネル構成

1. **エラーログ件数（Big Number）**
   - ビジュアライゼーション: Stat
   - クエリ: Count where `level:3`
   - 時間範囲: Last 24 hours
   - しきい値: > 50 (赤), > 20 (黄)

2. **エラーログ時系列**
   - ビジュアライゼーション: Time series (赤色)
   - クエリ: Count where `level:3` grouped by 1h
   - アラート設定: 10件/時間 を超えたら通知

3. **サービス別エラー分布**
   - ビジュアライゼーション: Pie chart
   - クエリ: Count where `level:3` grouped by `service.keyword`

4. **エラーメッセージTop 10**
   - ビジュアライゼーション: Table
   - クエリ: Terms aggregation on `message.keyword`
   - カラム: Message, Count, Percentage

5. **エラーログサンプル**
   - ビジュアライゼーション: Logs panel
   - クエリ: Latest 20 logs where `level:3`
   - 表示フィールド: @timestamp, service, message

#### レイアウト
```
┌──────────┬──────────────────────────────────┐
│ エラー   │  エラーログ時系列                │
│ 件数     │  (Time series with alert)        │
│ (Stat)   │                                  │
├──────────┴──────────────────┬───────────────┤
│ サービス別エラー分布        │ エラーTop 10  │
│ (Pie chart)                 │ (Table)       │
├─────────────────────────────┴───────────────┤
│  エラーログサンプル（Logs panel）           │
└─────────────────────────────────────────────┘
```

---

### Dashboard 3: サービス別ログメトリクス

**ファイル名**: `logs-service-metrics.json`

#### パネル構成

1. **サービス選択（Variable）**
   - 変数名: `service`
   - クエリ: Terms aggregation on `service.keyword`
   - Multi-select: Yes

2. **選択サービスのログ量推移**
   - ビジュアライゼーション: Time series
   - クエリ: Count where `service:$service`

3. **選択サービスのログレベル分布**
   - ビジュアライゼーション: Pie chart
   - クエリ: Count where `service:$service` grouped by `level`

4. **選択サービスのログサンプル**
   - ビジュアライゼーション: Logs panel
   - クエリ: Latest 50 logs where `service:$service`

#### 対象サービス（例）
- opensearch
- docker-opensearch-dashboards-start
- fluent-bit
- sshd-session
- systemd
- anomaly-detection-start

---

### Dashboard 4: 統合システム監視（既存ダッシュボード拡張）

**ファイル名**: `overview.json` (既存を拡張)

#### 追加パネル

1. **ログ収集状況**
   - OpenSearchインデックス件数
   - Fluent Bit稼働状況
   - ログ収集レート

2. **ログストレージ使用量**
   - OpenSearchディスク使用量
   - インデックスサイズ推移

3. **ログシステムヘルス**
   - OpenSearch cluster health
   - Fluent Bit up/down status
   - OpenSearch Dashboards up/down status

---

## 🚨 アラート設計

### Alert 1: エラーログ急増

```yaml
name: High Error Log Rate
condition: |
  Count of logs where level:3 in last 1h > 100
notification: Discord (既存のAlertmanager経由)
severity: Warning
description: "過去1時間でエラーログが100件を超えました"
```

### Alert 2: ログ収集停止

```yaml
name: Log Collection Stopped
condition: |
  No logs received in last 10 minutes
notification: Discord
severity: Critical
description: "ログ収集が10分間停止しています"
```

### Alert 3: OpenSearchダウン

```yaml
name: OpenSearch Down
condition: |
  OpenSearch cluster health != green for 5 minutes
notification: Discord
severity: Critical
description: "OpenSearchクラスターがダウンしています"
```

### Alert 4: 特定サービスのエラー

```yaml
name: Service Specific Errors
condition: |
  Count of logs where service:opensearch AND level:3 > 10 in last 1h
notification: Discord
severity: Warning
description: "OpenSearchサービスで1時間に10件以上のエラーが発生"
```

---

## 🛠️ 実装手順

### Phase 1: Data Source統合（所要時間: 30分）

#### Step 1: NixOS設定更新
```bash
# monitoring.nixを編集
vim systems/nixos/modules/services/monitoring.nix

# OpenSearch Data Source追加（上記設定参照）
```

#### Step 2: プラグイン確認
```bash
# nixpkgsでOpenSearchプラグインが利用可能か確認
nix search nixpkgs grafanaPlugins.opensearch

# 利用不可の場合、Elasticsearchプラグインで代用
```

#### Step 3: デプロイ
```bash
sudo nixos-rebuild switch --flake .#nixos

# Grafana再起動確認
sudo systemctl status grafana
```

#### Step 4: Data Source動作確認
```bash
# Grafana UIでData Sourcesを確認
# http://grafana.shinbunbun.com → Configuration → Data sources
# OpenSearchが追加されていることを確認

# Test & Save でクエリ実行確認
```

---

### Phase 2: ダッシュボード作成（所要時間: 2時間）

#### Step 1: ログ量監視ダッシュボード作成
1. Grafana UI → Create → Dashboard
2. パネルを上記設計に従って追加
3. クエリ設定（OpenSearch Data Source使用）
4. Export → JSON
5. 保存: `systems/nixos/modules/services/dashboards/logs-volume-metrics.json`

#### Step 2: エラーログ監視ダッシュボード作成
同様の手順で作成

#### Step 3: サービス別ログメトリクスダッシュボード作成
同様の手順で作成

#### Step 4: NixOSに統合
```bash
# ダッシュボードJSONファイルを配置
cp logs-*.json systems/nixos/modules/services/dashboards/

# NixOS再ビルド（自動プロビジョニング）
sudo nixos-rebuild switch --flake .#nixos
```

---

### Phase 3: アラート設定（所要時間: 1時間）

#### Step 1: アラートルール作成
Grafana UI → Alerting → Alert rules

#### Step 2: 通知チャンネル確認
既存のDiscord通知設定を確認・流用

#### Step 3: アラートテスト
```bash
# 意図的にエラーログを生成してテスト
logger -p error -t test-service "Test error message"

# アラートが発火するか確認
```

---

### Phase 4: ドキュメント作成（所要時間: 30分）

#### 作成するドキュメント
1. **運用手順書**
   - ダッシュボードの見方
   - アラート対応手順
   - トラブルシューティング

2. **設定リファレンス**
   - Data Source設定詳細
   - クエリ例集
   - カスタマイズ方法

---

## 🔄 Loki vs OpenSearch 使い分け

### Loki（既存）
- **用途**: リアルタイムログストリーミング
- **データソース**: systemd-journal → Promtail → Loki
- **保持期間**: 短期（数日）
- **強み**: 軽量、Prometheusとの統合、ラベルベース検索

### OpenSearch（新規）
- **用途**: 長期ログ保存・全文検索
- **データソース**: systemd-journal → Fluent Bit → OpenSearch
- **保持期間**: 中〜長期（30日）
- **強み**: 高度な検索、大量データ処理、ダッシュボード機能

### 推奨構成
```
systemd-journal
    ├→ Promtail → Loki (短期・リアルタイム)
    └→ Fluent Bit → OpenSearch (長期・全文検索)
```

**メリット**:
- リアルタイム監視はLoki（軽量・高速）
- 詳細分析・長期保存はOpenSearch
- 障害時の冗長性確保

---

## 📝 クエリ例集

### OpenSearch Data SourceでのGrafanaクエリ

#### 1. ログ件数の時系列
```json
{
  "query": "*",
  "alias": "Total Logs",
  "metrics": [
    {
      "type": "count",
      "id": "1"
    }
  ],
  "bucketAggs": [
    {
      "type": "date_histogram",
      "field": "@timestamp",
      "id": "2",
      "settings": {
        "interval": "1h",
        "min_doc_count": 0
      }
    }
  ]
}
```

#### 2. エラーログ件数
```json
{
  "query": "level:3",
  "alias": "Error Logs",
  "metrics": [
    {
      "type": "count",
      "id": "1"
    }
  ]
}
```

#### 3. サービス別ログ件数（Top 10）
```json
{
  "query": "*",
  "metrics": [
    {
      "type": "count",
      "id": "1"
    }
  ],
  "bucketAggs": [
    {
      "type": "terms",
      "field": "service.keyword",
      "id": "2",
      "settings": {
        "size": 10,
        "order": "desc",
        "orderBy": "_count"
      }
    }
  ]
}
```

#### 4. ログレベル分布
```json
{
  "query": "*",
  "metrics": [
    {
      "type": "count",
      "id": "1"
    }
  ],
  "bucketAggs": [
    {
      "type": "terms",
      "field": "level",
      "id": "2",
      "settings": {
        "size": 10
      }
    }
  ]
}
```

---

## ✅ チェックリスト

### Phase 1: Data Source統合
- [ ] monitoring.nixにOpenSearch Data Source設定追加
- [ ] プラグイン設定確認（opensearch or elasticsearch）
- [ ] NixOS再ビルド
- [ ] Grafana UIでData Source接続確認
- [ ] テストクエリ実行

### Phase 2: ダッシュボード作成
- [ ] ログ量監視ダッシュボード作成・テスト
- [ ] エラーログ監視ダッシュボード作成・テスト
- [ ] サービス別ログメトリクスダッシュボード作成・テスト
- [ ] JSONエクスポート
- [ ] dashboardsディレクトリに配置
- [ ] NixOS自動プロビジョニング確認

### Phase 3: アラート設定
- [ ] エラーログ急増アラート作成
- [ ] ログ収集停止アラート作成
- [ ] OpenSearchダウンアラート作成
- [ ] Discord通知テスト

### Phase 4: ドキュメント
- [ ] 運用手順書作成
- [ ] クエリ例集作成
- [ ] トラブルシューティングガイド作成

---

## 🎯 成果物

### 設定ファイル
1. `systems/nixos/modules/services/monitoring.nix` (更新)
   - OpenSearch Data Source設定追加

### ダッシュボードファイル
1. `systems/nixos/modules/services/dashboards/logs-volume-metrics.json` (新規)
2. `systems/nixos/modules/services/dashboards/logs-errors-monitoring.json` (新規)
3. `systems/nixos/modules/services/dashboards/logs-service-metrics.json` (新規)
4. `systems/nixos/modules/services/dashboards/overview.json` (更新)

### ドキュメント
1. `docs/grafana-opensearch-operation.md` (運用手順書)
2. `docs/grafana-opensearch-queries.md` (クエリリファレンス)

---

## 🚀 次のステップ

1. **Phase 1を実装** → Data Source統合完了
2. **Phase 2を実装** → 基本ダッシュボード完成
3. **Phase 3を実装** → アラート設定完了
4. **運用開始** → 1週間の動作確認
5. **Phase 4検討** → 高度な統合（必要に応じて）

---

## 📚 参考資料

- [Grafana OpenSearch Data Source Documentation](https://grafana.com/docs/grafana/latest/datasources/elasticsearch/)
- [OpenSearch Documentation](https://opensearch.org/docs/latest/)
- [Grafana Provisioning Documentation](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Alerting in Grafana](https://grafana.com/docs/grafana/latest/alerting/)

---

**作成日**: 2025-10-15
**更新日**: 2025-10-15
**ステータス**: 計画中

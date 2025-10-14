# OpenSearch導入実装計画書

## 概要

nixos-desktop（RAM 96GB）にOpenSearchを導入し、GCP Cloud Logging相当の高度なログ検索基盤を構築します。

## 環境情報

### ターゲットホスト
- **ホスト名**: nixos-desktop
- **IPアドレス**: 192.168.1.4
- **RAM**: 96GB
- **空きメモリ**: 十分なリソース確保可能
- **ディスク**: 152GB空き

### 既存のログ基盤
- **Loki**: 稼働中（nixos: 192.168.1.3、ポート3100）
- **Promtail**: 稼働中（各ホストでログ収集）
- **Grafana**: 稼働中（ポート3000）
- **ClickHouse**: 設定済み（未稼働）

---

## アーキテクチャ設計

### システム構成図

```
┌─────────────────────────────────────────────────────────────┐
│                      nixos-desktop (192.168.1.4)            │
│                         RAM: 96GB                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  OpenSearch Cluster (Single Node)                     │  │
│  │  - ポート: 9200 (HTTP), 9300 (Transport)             │  │
│  │  - JVMヒープ: 32GB (RAMの1/3推奨)                    │  │
│  │  - データディレクトリ: /var/lib/opensearch           │  │
│  │  - ログ保持期間: 30日                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  OpenSearch Dashboards                                │  │
│  │  - ポート: 5601                                       │  │
│  │  - UI: ログ検索・可視化・ダッシュボード              │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↑                                    │
└─────────────────────────┼─────────────────────────────────────┘
                          │
        ┌─────────────────┴─────────────────┐
        │                                     │
┌───────┴────────┐                  ┌────────┴──────┐
│  nixos         │                  │ nixos-desktop │
│  (192.168.1.3) │                  │ (192.168.1.4) │
├────────────────┤                  ├───────────────┤
│  Fluent Bit    │                  │  Fluent Bit   │
│  - journal     │                  │  - journal    │
│  - nginx logs  │                  │  - nginx logs │
│  - app logs    │                  │  - app logs   │
└────────────────┘                  └───────────────┘
```

### データフロー

```
systemd-journal + nginx logs + application logs
                ↓
           Fluent Bit
    (ログの収集・整形・エンリッチ)
                ↓
         OpenSearch (9200)
    (インデックス化・保存・検索)
                ↓
    OpenSearch Dashboards (5601)
         (検索UI・可視化)
```

### 既存システムとの統合

```
┌──────────────────────────────────────────┐
│         統合ログ基盤                      │
├──────────────────────────────────────────┤
│                                            │
│  OpenSearch (nixos-desktop)               │
│    ├─ 高度な全文検索                     │
│    ├─ 複雑なクエリ・集計                 │
│    ├─ ダッシュボード・可視化             │
│    └─ 機械学習ベース異常検知             │
│                                            │
│  Loki (nixos)                             │
│    ├─ リアルタイムログストリーミング     │
│    ├─ Grafanaとの統合                    │
│    └─ メトリクスとの相関分析             │
│                                            │
│  Grafana (nixos)                          │
│    ├─ メトリクス監視                     │
│    ├─ Lokiログ表示                       │
│    └─ アラート管理                       │
│                                            │
└──────────────────────────────────────────┘
```

---

## 実装フェーズ

### フェーズ1: OpenSearchセットアップ（1-2日）

#### 1.1 config.nixへの設定追加

`shared/config.nix`に以下を追加：

```nix
# OpenSearch設定
opensearch = {
  # サーバー設定
  port = 9200;              # HTTP API
  transportPort = 9300;     # ノード間通信
  dataDir = "/var/lib/opensearch";

  # メモリ設定（96GBの1/3 = 32GB）
  heapSize = "32g";
  maxMemory = 34359738368;  # 32GB + 2GB（システム用）

  # クラスター設定
  clusterName = "shinbunbun-logs";
  nodeName = "nixos-desktop";

  # インデックス設定
  retentionDays = 30;
  numberOfShards = 1;       # 単一ノードのため
  numberOfReplicas = 0;     # レプリカ不要

  # セキュリティ設定
  enableSecurity = true;
  allowedNetworks = [
    "192.168.1.0/24"
    "192.168.11.0/24"
    "10.100.0.0/24"         # WireGuard
  ];
};

# OpenSearch Dashboards設定
opensearchDashboards = {
  port = 5601;
  domain = "opensearch.shinbunbun.com";
  opensearchUrl = "http://192.168.1.4:9200";
};

# Fluent Bit設定
fluentBit = {
  port = 2020;              # メトリクス
  opensearchHost = "192.168.1.4";
  opensearchPort = 9200;
};
```

#### 1.2 OpenSearchモジュール作成

**ファイル**: `systems/nixos/modules/services/opensearch.nix`

主な設定内容：
- OpenSearchサービスの定義
- JVMオプションの設定
- クラスター設定（単一ノード）
- インデックステンプレート
- ILM（Index Lifecycle Management）ポリシー
- セキュリティ設定
- ファイアウォールルール
- systemdサービス設定

#### 1.3 OpenSearch Dashboardsモジュール作成

**ファイル**: `systems/nixos/modules/services/opensearch-dashboards.nix`

主な設定内容：
- Dashboardsサービスの定義
- OpenSearch接続設定
- 認証設定（内部ネットワーク限定）
- ファイアウォールルール

#### 1.4 nixos-desktop設定への追加

nixos-desktopの設定ファイルに以下をインポート：
```nix
imports = [
  ./modules/services/opensearch.nix
  ./modules/services/opensearch-dashboards.nix
];
```

---

### フェーズ2: Fluent Bit導入（1日）

#### 2.1 Fluent Bitモジュール作成

**ファイル**: `systems/nixos/modules/services/fluent-bit.nix`

**収集するログ**：
1. systemd-journal
2. Nginxアクセスログ
3. Nginxエラーログ
4. アプリケーションログ（JSON）

**主な機能**：
- ログのパース・エンリッチ
- タイムスタンプの正規化
- フィールドの抽出（level, service, host等）
- OpenSearchへのバルク送信
- リトライ・バックオフ設定

#### 2.2 既存Promtailとの並行稼働

移行期間中は両方を稼働：
- **Promtail → Loki**: 既存の設定で継続
- **Fluent Bit → OpenSearch**: 新規追加

---

### フェーズ3: インデックス設計（1日）

#### 3.1 インデックステンプレート

**logs-*パターン**

```json
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.refresh_interval": "5s",
      "index.codec": "best_compression"
    },
    "mappings": {
      "properties": {
        "@timestamp": { "type": "date" },
        "level": {
          "type": "keyword",
          "fields": {
            "text": { "type": "text" }
          }
        },
        "message": {
          "type": "text",
          "fields": {
            "keyword": { "type": "keyword", "ignore_above": 256 }
          }
        },
        "host": { "type": "keyword" },
        "service": { "type": "keyword" },
        "unit": { "type": "keyword" },
        "job": { "type": "keyword" },
        "log_type": { "type": "keyword" },
        "method": { "type": "keyword" },
        "status": { "type": "short" },
        "trace_id": { "type": "keyword" }
      }
    }
  }
}
```

#### 3.2 Index Lifecycle Management (ILM)

**30日保持ポリシー**

```json
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_age": "1d",
            "max_size": "50gb"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "forcemerge": {
            "max_num_segments": 1
          },
          "shrink": {
            "number_of_shards": 1
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

---

### フェーズ4: ダッシュボード・可視化（2-3日）

#### 4.1 基本ダッシュボード

**1. ログエクスプローラー**
- 全ログの時系列表示
- フィルタ機能（level, service, host）
- リアルタイム更新
- 検索ボックス

**2. エラー分析ダッシュボード**
- エラーレベルの分布（円グラフ）
- エラー数の推移（時系列グラフ）
- トップエラーメッセージ（テーブル）
- サービス別エラー数（棒グラフ）

**3. サービス監視ダッシュボード**
- サービス別ログ量（棒グラフ）
- サービス別エラー率（ヒートマップ）
- レスポンスタイム分布（ヒストグラム）
- 異常なパターンの検出

**4. Nginx監視ダッシュボード**
- アクセス数の推移
- HTTPステータス別の分布
- トップURLランキング
- エラー率の推移

#### 4.2 保存済みクエリ

よく使うクエリを保存：

```
# エラーログのみ
level:error OR level:critical OR level:emergency

# 特定サービスのログ
service:"nginx" AND level:error

# トレースID検索
trace_id:"abc123def456"

# レスポンスタイム遅延
status:200 AND response_time:>1000

# 過去1時間のクリティカルエラー
level:critical AND @timestamp:[now-1h TO now]
```

---

### フェーズ5: 高度な機能（必要に応じて）

#### 5.1 異常検知

OpenSearch MLプラグインを使用：
- ログパターンの異常検出
- レート異常の検出
- 季節性を考慮した異常検知

#### 5.2 アラート設定

OpenSearch Alertingプラグイン：
- エラー急増の通知
- 特定パターンの検知（Kernel Panic等）
- SLO違反の通知

#### 5.3 外部システム連携

- **Grafana**: OpenSearchデータソース追加
- **Alertmanager**: アラート通知の統合
- **Slack/Discord**: 通知チャンネル連携

---

## リソース設計

### メモリ割り当て（96GB中）

| コンポーネント | 割り当て | 用途 |
|---------------|---------|------|
| OpenSearch JVMヒープ | 32GB | インデックス・検索処理 |
| OpenSearchオフヒープ | 8GB | ファイルシステムキャッシュ |
| OpenSearch Dashboards | 2GB | UI・可視化 |
| Fluent Bit | 512MB | ログ収集・転送 |
| システム予約 | 10GB | OS・その他サービス |
| **空きメモリ** | **43.5GB** | 将来の拡張用 |

### ディスク使用量見積もり

**1日あたりのログ量**（実測値から推定）：
- systemd-journal: 約2GB/日
- Nginxログ: 約500MB/日
- アプリケーションログ: 約300MB/日
- **合計**: 約2.8GB/日

**30日保持の場合**：
- 生ログ: 2.8GB × 30 = 84GB
- インデックス: 約20GB（メタデータ等）
- **合計**: 約104GB

**現在の空き容量**: 152GB → **十分**

### CPU使用量

- **通常時**: 2-4コア（10-20%）
- **ピーク時**: 8-12コア（インデックス処理時）
- **クエリ実行時**: 4-8コア

---

## セキュリティ設計

### ネットワークセキュリティ

1. **ファイアウォール制限**
   - 許可ネットワーク: 192.168.1.0/24, 192.168.11.0/24, 10.100.0.0/24
   - ポート: 9200, 9300, 5601

2. **通信の暗号化**
   - フェーズ1: HTTP（内部ネットワークのみ）
   - フェーズ2: HTTPS（証明書設定）

### 認証・認可

1. **内部認証**
   - OpenSearch Security Plugin
   - 内部ユーザー管理
   - ロールベースアクセス制御（RBAC）

2. **外部認証（将来）**
   - Authentik統合
   - SAML/OIDC

---

## 運用設計

### 監視項目

**OpenSearch監視**（Prometheus経由）：
- ヒープ使用率
- GC実行時間
- クエリレイテンシ
- インデックス速度
- ディスク使用率
- クラスター状態

**アラート条件**：
- ヒープ使用率 > 85%
- GC時間 > 1秒
- クエリレイテンシ > 5秒
- ディスク使用率 > 80%
- クラスター状態 != green

### バックアップ戦略

1. **スナップショット**
   - 頻度: 毎日1回
   - 保持: 7日分
   - 保存先: /var/backup/opensearch

2. **リストア手順**
   - スナップショットからのリストア
   - インデックス再構築
   - 検証手順

### メンテナンス

**定期メンテナンス**：
- インデックスの最適化（週1回）
- 古いインデックスの削除（自動）
- パフォーマンスチューニング（月1回）

**アップグレード手順**：
1. スナップショット作成
2. サービス停止
3. パッケージ更新
4. 設定確認
5. サービス再起動
6. 動作確認

---

## パフォーマンスチューニング

### JVMオプション

```
-Xms32g
-Xmx32g
-XX:+UseG1GC
-XX:G1ReservePercent=25
-XX:InitiatingHeapOccupancyPercent=30
-XX:MaxGCPauseMillis=200
-XX:+ParallelRefProcEnabled
-XX:+UnlockExperimentalVMOptions
-XX:+UnlockDiagnosticVMOptions
-XX:G1NumCollectionsKeepPinned=10000000
```

### OpenSearch設定

```yaml
# クエリキャッシュ
indices.queries.cache.size: 20%

# リクエストキャッシュ
indices.requests.cache.size: 5%

# フィールドデータキャッシュ
indices.fielddata.cache.size: 30%

# バルクキューサイズ
thread_pool.write.queue_size: 1000

# 検索キューサイズ
thread_pool.search.queue_size: 2000
```

---

## クエリ例

### 基本検索

```
# すべてのエラーログ
level:error

# 特定サービスのログ
service:nginx

# 時間範囲指定
@timestamp:[2025-10-14T00:00:00 TO 2025-10-14T23:59:59]

# 複合条件
service:nginx AND level:error AND @timestamp:[now-1h TO now]
```

### 高度な検索

```
# 正規表現
message:/kernel.panic.*/

# ワイルドカード
message:*timeout*

# 範囲検索
status:[400 TO 599]

# 存在チェック
_exists_:trace_id

# ブール演算
(level:error OR level:critical) AND service:nginx
```

### 集計クエリ

```json
{
  "size": 0,
  "aggs": {
    "error_by_service": {
      "terms": {
        "field": "service",
        "size": 10
      },
      "aggs": {
        "error_count": {
          "filter": {
            "term": { "level": "error" }
          }
        }
      }
    }
  }
}
```

---

## トラブルシューティング

### よくある問題と対処法

#### 1. OpenSearchが起動しない

**原因**:
- メモリ不足
- ポートの競合
- 設定ファイルのエラー

**対処法**:
```bash
# ログ確認
journalctl -u opensearch -n 100

# 設定検証
/usr/share/opensearch/bin/opensearch-node --dry-run

# ポート確認
ss -tlnp | grep 9200
```

#### 2. 検索が遅い

**原因**:
- インデックスの断片化
- ヒープ不足
- 不適切なクエリ

**対処法**:
```bash
# インデックス最適化
curl -X POST "localhost:9200/logs-*/_forcemerge?max_num_segments=1"

# キャッシュクリア
curl -X POST "localhost:9200/_cache/clear"
```

#### 3. ディスク容量不足

**原因**:
- ILMが動作していない
- 予想以上のログ量

**対処法**:
```bash
# 古いインデックス手動削除
curl -X DELETE "localhost:9200/logs-2025.09.*"

# ILM状態確認
curl "localhost:9200/_plugins/_ism/explain/logs-*"
```

---

## 移行計画

### 既存システムからの移行

**段階的移行**：

1. **Phase 1**: OpenSearch単独稼働（1週間）
   - Fluent Bit → OpenSearch
   - Promtail → Loki（継続）
   - 両システム並行運用

2. **Phase 2**: 評価期間（2週間）
   - パフォーマンス評価
   - 検索機能の評価
   - ユーザーフィードバック収集

3. **Phase 3**: 本格運用（1ヶ月後）
   - OpenSearchをメイン検索基盤に
   - Lokiはリアルタイムストリーミング用に継続
   - ClickHouseは長期保存用（オプション）

### ロールバック計画

問題発生時の対応：
1. Fluent Bitを停止
2. Promtailのみでログ収集継続
3. OpenSearchのトラブル解決
4. 再度切り替え

---

## 成功指標（KPI）

### 技術指標

- **検索速度**: 95%のクエリが3秒以内に完了
- **インデックス速度**: 10,000 docs/sec以上
- **稼働率**: 99.9%以上
- **ディスク使用率**: 80%以下を維持

### ユーザー体験指標

- **ログ検索の容易さ**: 目的のログを5分以内に発見
- **ダッシュボードの応答性**: 3秒以内のレンダリング
- **アラート精度**: 誤検知率10%以下

---

## コスト分析

### リソースコスト

- **ハードウェア**: 既存インフラ活用（追加コスト0円）
- **ライセンス**: Apache 2.0（無料）
- **運用工数**: 週2時間（初期は週5時間）

### ROI（投資対効果）

**メリット**：
- GCP Cloud Loggingコスト削減: 月額$500-1000削減
- ログ検索時間短縮: 1日30分 → 1日5分（25分削減）
- インシデント対応速度向上: 平均30%短縮

**投資**：
- 初期セットアップ: 5日間
- 学習コスト: 2週間

---

## タイムライン

### 全体スケジュール（2週間）

| 期間 | フェーズ | タスク | 担当 | 状態 |
|-----|---------|-------|------|-----|
| 1日目 | Phase 1 | config.nix設定追加 | - | 未着手 |
| 2日目 | Phase 1 | opensearch.nix作成 | - | 未着手 |
| 3日目 | Phase 1 | opensearch-dashboards.nix作成 | - | 未着手 |
| 4日目 | Phase 2 | fluent-bit.nix作成 | - | 未着手 |
| 5日目 | Phase 2 | ログ収集テスト | - | 未着手 |
| 6-7日目 | Phase 3 | インデックステンプレート作成 | - | 未着手 |
| 8-10日目 | Phase 4 | ダッシュボード作成 | - | 未着手 |
| 11-12日目 | Phase 5 | 異常検知・アラート設定 | - | 未着手 |
| 13-14日目 | 運用 | ドキュメント整備・移行 | - | 未着手 |

---

## 参考資料

### ドキュメント

- [OpenSearch公式ドキュメント](https://opensearch.org/docs/latest/)
- [OpenSearch Dashboards Guide](https://opensearch.org/docs/latest/dashboards/)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)

### NixOS関連

- [NixOS OpenSearch Package](https://search.nixos.org/packages?query=opensearch)
- [NixOS Services Options](https://search.nixos.org/options?query=opensearch)

### 既存ドキュメント

- `docs/log-analyze-plan.md`: ログ分析計画
- `docs/monitoring-implementation-plan.md`: 監視実装計画

---

## 付録

### A. 用語集

- **ILM (Index Lifecycle Management)**: インデックスのライフサイクル管理
- **ISM (Index State Management)**: OpenSearch独自のインデックス管理機能
- **Shard**: インデックスの分割単位
- **Replica**: データの複製
- **Hot-Warm-Cold Architecture**: データのアクセス頻度による階層管理

### B. チェックリスト

**導入前チェック**:
- [ ] ディスク容量確認（最低150GB必要）
- [ ] メモリ確認（最低40GB必要）
- [ ] ネットワーク設定確認
- [ ] バックアップ計画策定

**導入後チェック**:
- [ ] OpenSearchクラスター状態確認
- [ ] インデックス作成確認
- [ ] ログ収集動作確認
- [ ] ダッシュボードアクセス確認
- [ ] アラート動作確認

### C. 連絡先

- **技術サポート**: OpenSearch Community Forum
- **緊急連絡**: システム管理者

---

## 変更履歴

| 日付 | バージョン | 変更内容 | 担当 |
|-----|-----------|---------|------|
| 2025-10-14 | 1.0 | 初版作成 | Claude |

---

## 承認

| 役割 | 氏名 | 承認日 | 署名 |
|-----|------|-------|------|
| 作成者 | - | 2025-10-14 | - |
| レビュー | - | - | - |
| 承認者 | - | - | - |

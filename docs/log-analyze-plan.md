# 簡易設計方針（サマリ）

## デプロイ構成（ハイブリッド）

### homeMachine（安定稼働優先）
**役割**: 監視基盤のコア機能を安定運用
- **既存**: Prometheus、Grafana、Alertmanager
- **新規追加**: Loki（Phase 1）
- **特徴**: 低スペックだが安定稼働、24/7運用

### nixos-desktop（高負荷処理担当）
**役割**: 重い分析処理を実行
- **新規追加**: 
  - ClickHouse（Phase 2）
  - 異常検知ジョブ（Python/ML）
  - Parquetエクスポート処理
- **特徴**: 高スペック、若干不安定でも影響限定的

### データフロー
```
各ホスト → Vector/Promtail → Loki(homeMachine) → ClickHouse(nixos-desktop)
                              ↓
                          Grafana(homeMachine) ← ClickHouse(nixos-desktop)
```

### メリット
- 基幹監視機能の高可用性確保
- リソース使用の最適化
- 障害時の影響範囲限定
- 段階的な拡張が容易

## 目的 / KPI

* **目的**：Cockpitの“単体目視”を超え、**横断検索・自動検知・再発防止**を実現。
* **KPI**：MTTD/MTTR短縮、アラートのノイズ率低下、同型インシデント再発間隔の伸長、失敗率/遅延改善。

## スコープ

* **対象**：NixOSホスト群 + RouterOS（syslog）+ Nginx/アプリログ。
* **非対象（初期）**：本格SIEM、長期監査（>1年）の厳密運用（必要時に段階追加）。

## アーキテクチャ概要

* **収集**：Vector（推奨）または Promtail。`journald/nginx/アプリJSON` を**構造化**し共通フィールド付与。
* **横断検索**：**Loki@homeMachine**（14–30日保持）— 開発/運用の"即時探索"用。安定稼働優先。
* **分析**：**ClickHouse@nixos-desktop**（30–180日保持）— 集計/異常検知/ダッシュボード。高負荷処理担当。
* **可視化**：Grafana@homeMachine（既存）。Loki（同一ホスト）& ClickHouse（nixos-desktop）をデータソース登録。
* **通知**：Alertmanager@homeMachine→Discord（既存ルート流用）。
* **補助**：Cockpitは各ホストのGUIとして継続利用。必要なら後段でOpenSearch併用（監査・全文特化）。

## データ設計（最小）

* **共通フィールド**：`ts, host, service, unit, level, path, status, latency_ms, trace_id, message, attrs(JSON)`
* **Loki ラベル**：`host, service, unit, level`（クエリ軸を厳選）。
* **ClickHouse**：`logs.app_logs`（原本）＋ 1分集計MV（`cnt, err, s5xx, err_rate, s5xx_rate`）。

## 保持 / 運用

* **Loki@homeMachine**：短〜中期（14–30日）。低スペックでも運用可能な範囲。後で S3/boltdb-shipper へ拡張可。
* **ClickHouse@nixos-desktop**：中期（30–180日）TTL削除＋週次で **S3/MinIOへParquet** エクスポート（長期/監査）。高スペックを活用。
* **バックアップ**：
  - Lokiデータ: homeMachineでローカルバックアップ
  - CHメタデータ: nixos-desktopでGit管理
  - ダッシュボードJSON: homeMachineでGit管理
  - Parquet: nixos-desktopからS3/MinIOへ（バージョン付与）

## 解析（初期の"効く"セット）

* **異常検知@nixos-desktop**：IsolationForest（5分毎）で「いつもと違う」上位のみを `logs.anomalies` に記録。高負荷処理をnixos-desktopで実行。
* **テンプレ化（任意）@nixos-desktop**：Drain系でログ本文をテンプレID化→"新出/急増"検知。
* **ドリルダウン**：異常→ClickHouse@nixos-desktop明細→Loki@homeMachineで原文→関連メトリクス@homeMachine（p95/エラーレート）へ。

## 可視化 / アラート

* **ダッシュボード@Grafana(homeMachine)**：
  - ①サービス別エラーレート（Loki直接クエリ）
  - ②遅延分布/5xx（ClickHouse@nixos-desktopから取得）
  - ③異常ウォール（ClickHouse@nixos-desktopのscoreデータ）
* **アラート@Alertmanager(homeMachine)**：5分窓×30分窓の二段しきい値（両方超で通知）。SLO系（burn rate）を順次追加。

## セキュリティ / 公開

* **認証**：Grafanaを **Authentik OIDC** 連携（閲覧/編集のRBAC）。
* **公開**：**Cloudflare Tunnel** 経由（直開け禁止）。管理系はIP制限/グループ制御。
* **秘匿**：`secrets/`（sops-nix等）で統一。収集側でPIIマスキング。

## ロールアウト（段階導入）

1. **Phase 1（横断）@homeMachine**：✅ **完了 (2025-01-14)**
   - Loki導入（homeMachineにデプロイ）✅
   - Vector/Promtailで全ホスト集約 ✅
   - 既存Grafanaにデータソース登録 ✅
   - 二段アラート設定（既存Alertmanager活用）✅

2. **Phase 2（分析）@nixos-desktop**：✅ **完了 (2025-01-15)**
   - ClickHouse追加（nixos-desktopにデプロイ）✅
   - 1分集計MV構築 ✅
   - 異常検知ジョブ実装（Python環境構築）✅
   - Grafanaから両ホストのデータソース参照 ✅
   - "異常ウォール"可視化 ✅

3. **Phase 3（必要時）**：
   - OpenSearch併用（監査/全文）- デプロイ先は要検討
   - S3/MinIOレイク強化
   - OTel導入でTrace相関

## 受け入れ基準

* Grafana Exploreで**全ホスト横断**検索が可能。
* Discordに**意味のあるアラート**（二段）が届く（誤報率が実感レベルで低下）。
* “異常ウォール”で上位スコア事象を確認→**数クリックで原因候補**に到達。
* 1か月運用後、**無駄ログ削減**や復旧時間短縮が指標で確認できる。

## 実装状況（2025-01-15時点）

### Phase 1 ✅ 完了
**実装ファイル:**
- `systems/nixos/modules/services/loki.nix` - Lokiサービス設定
- `systems/nixos/modules/services/promtail.nix` - ログ収集エージェント
- `systems/nixos/modules/services/loki-rules.yaml` - アラートルール

**動作確認済み:**
- homeMachineでLoki稼働中（ポート3100）
- 全ホストからPromtail経由でログ収集
- 30日間のログ保持
- Grafanaでクエリ可能

### Phase 2 ✅ 完了  
**実装ファイル:**
- `systems/nixos/modules/services/clickhouse.nix` - ClickHouseデータベース
- `systems/nixos/modules/services/anomaly-detection.nix` - 異常検知サービス
- `systems/nixos/modules/services/anomaly-detection.py` - Isolation Forest実装
- `systems/nixos/modules/services/loki-to-clickhouse.py` - データ転送スクリプト
- `systems/nixos/modules/services/dashboards/anomaly-wall.json` - 異常ウォールダッシュボード

**動作確認済み:**
- nixos-desktopでClickHouse稼働中（ポート8123）
- 918件のログをClickHouseに保存済み
- 1分集計マテリアライズドビュー動作中（27件の集計データ）
- 5分ごとのLoki→ClickHouse転送動作中
- 異常検知ジョブタイマー設定済み（5分ごと実行）
- GrafanaにClickHouseデータソース追加済み

### 残タスク
- homeMachineでのGrafana設定反映（`sudo nixos-rebuild switch`）
- 異常ウォールダッシュボードの動作確認
- 初回異常検知実行の確認（01:30頃）


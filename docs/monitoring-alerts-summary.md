# 監視アラート設定まとめ

## 概要

このドキュメントは、実装された監視アラートの詳細な設定と閾値について記載しています。

## アラートグループ

### 1. システム監視 (system)

#### インスタンス監視
- **InstanceDown**: インスタンスがダウンしている
  - 条件: `up == 0`
  - 継続時間: 2分
  - 重要度: critical

#### リソース監視
- **HighCPUUsage**: 高CPU使用率
  - 条件: CPU使用率 > 80%
  - 継続時間: 5分
  - 重要度: warning

- **HighMemoryUsage**: 高メモリ使用率
  - 条件: メモリ使用率 > 85%
  - 継続時間: 5分
  - 重要度: warning

- **DiskSpaceLow**: ディスク容量不足
  - 条件: ディスク使用率 > 85%
  - 継続時間: 5分
  - 重要度: warning

- **HighSystemLoad**: 高システムロード
  - 条件: 5分間のロードアベレージ > CPUコア数の2倍
  - 継続時間: 5分
  - 重要度: warning

- **HighInodeUsage**: 高inode使用率
  - 条件: inode使用率 > 85%
  - 継続時間: 5分
  - 重要度: warning

#### ネットワーク監視
- **NetworkInterfaceDown**: ネットワークインターフェースダウン
  - 条件: インターフェース状態 = down（lo、docker、veth等を除く）
  - 継続時間: 2分
  - 重要度: critical

- **HighNetworkTrafficIn/Out**: 高ネットワークトラフィック
  - 条件: トラフィック > 100MB/s
  - 継続時間: 5分
  - 重要度: warning

- **HighPacketLossReceive**: パケット受信エラー
  - 条件: エラー率 > 0.01エラー/秒
  - 継続時間: 5分
  - 重要度: warning

#### Systemdサービス監視
- **SystemdServiceFailed**: Systemdサービス失敗
  - 条件: サービス状態 = failed
  - 継続時間: 2分
  - 重要度: critical

- **SystemdServiceFlapping**: サービスフラッピング
  - 条件: 15分間に3回以上の再起動
  - 継続時間: 5分
  - 重要度: warning

#### ディスクI/O監視
- **HighDiskIOUtilization**: 高ディスクI/O使用率
  - 条件: I/O使用率 > 90%
  - 継続時間: 5分
  - 重要度: warning

#### 時刻同期監視（新規追加）
- **ClockSkewDetected**: 時刻ずれ検出
  - 条件: NTP時刻との差 > 5秒
  - 継続時間: 5分
  - 重要度: warning

- **NTPSyncFailed**: NTP同期失敗
  - 条件: NTP同期状態 = 失敗
  - 継続時間: 10分
  - 重要度: critical

#### バックアップ監視（新規追加）
- **RouterOSBackupFailed**: RouterOSバックアップ失敗
  - 条件: routeros-backup.service状態 = failed
  - 継続時間: 5分
  - 重要度: critical

- **RouterOSBackupStale**: RouterOSバックアップ長時間未実行
  - 条件: 最終実行から25時間以上経過（systemdタイマーのRandomizedDelaySec考慮）
  - 継続時間: 1時間
  - 重要度: warning

#### ログ監視（新規追加）
- **DiskUsageRapidIncrease**: ディスク使用量の急激な増加
  - 条件: 1時間で100MB以上の増加
  - 継続時間: 10分
  - 重要度: warning

### 2. RouterOS監視 (routeros)

#### インターフェース監視
- **RouterOSInterfaceDown**: インターフェースダウン
  - 条件: インターフェース状態 = down（未使用インターフェースを除外: ifIndex 2,4,5,7,8）
  - 継続時間: 2分
  - 重要度: critical

- **RouterOSInterfaceErrors**: インターフェースエラー
  - 条件: 
    - 通常インターフェース: エラー率 > 0.01エラー/秒
    - WireGuard（ifIndex=12）: エラー率 > 0.1エラー/秒（VPNの特性を考慮）
  - 継続時間: 5分
  - 重要度: warning

#### システムリソース監視
- **RouterOSHighTemperature**: 高温度
  - 条件: 温度 > 60°C
  - 継続時間: 5分
  - 重要度: warning

- **RouterOSHighCPU**: 高CPU使用率
  - 条件: CPU使用率 > 80%
  - 継続時間: 5分
  - 重要度: warning

- **RouterOSHighMemoryUsage**: 高メモリ使用率
  - 条件: メモリ使用率 > 85%
  - 継続時間: 5分
  - 重要度: warning

#### VPN監視
- **RouterOSWireGuardDown**: WireGuardインターフェースダウン
  - 条件: WireGuardインターフェース（ifIndex=12）状態 = down
  - 継続時間: 2分
  - 重要度: critical

- **RouterOSWireGuardNoTraffic**: WireGuardトラフィックなし
  - 条件: 10分間トラフィックなし
  - 継続時間: 10分
  - 重要度: warning

#### PPPoE監視
- **RouterOSPPPoEDown**: PPPoE接続ダウン
  - 条件: PPPoEインターフェース（ifIndex=10）状態 = down
  - 継続時間: 2分
  - 重要度: critical

### 3. ディスクヘルス監視 (disk-health)

- **DiskSMARTErrors**: ディスクエラー検出
  - 条件: 読み取り/書き込みエラー > 0
  - 継続時間: 5分
  - 重要度: critical

## 実装の特徴

### 閾値の根拠

1. **時刻同期**: 5秒の閾値は、一般的なアプリケーションの許容範囲
2. **バックアップ**: 25時間の閾値は、dailyタイマー + 1時間のランダム遅延を考慮
3. **WireGuardエラー**: 0.1エラー/秒の高い閾値は、VPN接続の特性（パケットロス許容）を反映
4. **リソース使用率**: 85%の閾値は、余裕を持った運用のため

### 改善された点

1. **誤検知の削減**
   - 未使用RouterOSインターフェースの除外
   - WireGuardエラー閾値の調整
   - バックアップタイマーのランダム遅延考慮

2. **可視性の向上**
   - NTP同期状態のGrafanaパネル追加
   - バックアップ状態のGrafanaパネル追加
   - Systemdサービス状態の表形式表示

3. **運用性の向上**
   - アラートメッセージの日本語化対応
   - 具体的なトラブルシューティング手順の記載

## 今後の改善案

1. **カスタムメトリクス**
   - アプリケーション固有のメトリクス追加
   - ビジネスメトリクスの監視

2. **高度なアラート**
   - 予測的アラート（機械学習）
   - 複合条件によるアラート

3. **自動復旧**
   - アラート発生時の自動対処
   - エスカレーション機能

4. **RouterOS高度な監視**
   - ファイアウォール接続数監視（RouterOS側のSNMP OID未サポートのため実装不可）
   - ファイアウォールルール統計（RouterOS側のSNMP OID未サポートのため実装不可）

## 運用ガイドライン

### アラート対応

1. **Critical**: 即時対応必要
   - サービス影響の確認
   - 復旧作業の実施

2. **Warning**: 計画的対応
   - 原因調査
   - 予防的メンテナンス

### 閾値調整

- 初期運用後、実際の使用パターンに基づいて調整
- 季節変動や業務パターンを考慮
- 変更時は必ずドキュメント更新

### メンテナンス

- 月次でアラート発生履歴をレビュー
- 不要なアラートの削除・統合
- 新規要件に基づくアラート追加
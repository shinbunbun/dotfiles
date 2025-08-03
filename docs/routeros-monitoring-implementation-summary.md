# RouterOS監視機能実装まとめ

## 概要
GitHub Issue #107に基づき、RouterOSの監視機能を大幅に拡張しました。
940個の利用可能なOIDから実用的なものを選定し、監視システムに実装しました。

## 実装した機能

### 1. SNMP監視の拡張

#### 新規追加メトリクス
- **システムヘルス**
  - `mtxrSystemRebootCount`: システム再起動回数
  - `mtxrSystemBadBlocks`: メモリ不良ブロック数
  - `mtxrSystemUSBPowerResets`: USB電源リセット回数

- **DHCP監視**
  - `mtxrDHCPLeaseCount`: アクティブDHCPリース数

- **バージョン管理**
  - `mtxrSystemCurrentVersion`: 現在のRouterOSバージョン
  - `mtxrSystemUpgradeVersion`: 利用可能なアップグレードバージョン

- **詳細インターフェース統計**
  - `mtxrInterfaceRxDrop`: 受信パケットドロップ数
  - `mtxrInterfaceTxDrop`: 送信パケットドロップ数
  - `mtxrInterfaceRxError`: 受信エラー数
  - `mtxrInterfaceTxError`: 送信エラー数

### 2. Grafanaダッシュボードの拡張

#### 新規追加パネル
1. **システムヘルス表示**
   - アクティブDHCPリース数（現在値）
   - システム再起動回数
   - 不良ブロック数
   - USB電源リセット回数

2. **バージョン情報**
   - 現在のバージョン表示
   - 利用可能なアップグレード表示

3. **ネットワーク品質監視**
   - DHCPリース数推移（時系列グラフ）
   - パケットドロップ率（時系列グラフ）
   - 累計パケットドロップ数（バーゲージ）

### 3. アラート設定の追加

#### システムヘルスアラート
- **RouterOSRestarted**: システム再起動を検知
- **RouterOSBadBlocks**: メモリ不良ブロックを検出
- **RouterOSUSBPowerIssue**: USB電源問題を検知

#### ネットワーク監視アラート
- **DHCPPoolNearExhaustion**: DHCPプール枯渇警告（200リース以上）
- **RouterOSHighErrorRate**: インターフェースエラー率警告（100エラー/秒以上）
- **RouterOSHighPacketDropRate**: パケットドロップ率警告（1000パケット/秒以上）

## 発見された問題

監視実装中に以下の問題を発見しました：

### sfp1インターフェースの異常
- 受信ドロップ: 約3,025万パケット
- 送信ドロップ: 約1,698万パケット
- 受信エラー: 約507万
- 送信エラー: 約1億2,873万

→ sfp1の設定または物理的な接続に問題がある可能性があります。

## ファイル構成

### 設定ファイル
- `/cells/core/nixosProfiles/snmp.yml`: SNMP Exporter設定
- `/cells/core/nixosProfiles/alertmanager.nix`: アラート設定
- `/cells/core/nixosProfiles/dashboards/routeros.json`: Grafanaダッシュボード

### ドキュメント
- `/docs/routeros-all-oids-investigation.md`: 全940 OIDの調査結果
- `/docs/routeros-recommended-oids.md`: 推奨OIDリスト
- `/docs/routeros-snmp-testing.md`: SNMP動作確認手順
- `/docs/routeros-alerts-testing.md`: アラート動作確認手順

## 今後の推奨事項

### 1. 監視の調整
- DHCPプール枯渇アラートの閾値をプールサイズに合わせて調整
- パケットドロップ率の閾値をネットワーク規模に合わせて調整

### 2. 追加可能な監視項目
- PoE監視（現在は使用されていないため見送り）
- 無線インターフェース統計
- ルーティングテーブル監視

### 3. sfp1問題の対処
- インターフェース設定の確認
- ケーブルや光モジュールの確認
- 対向機器との互換性確認

## まとめ

RouterOSの監視機能を大幅に強化し、システムの健全性とネットワーク品質を
詳細に把握できるようになりました。特に以下の点で改善されました：

1. **予防的メンテナンス**: 再起動回数や不良ブロックの監視により問題を早期発見
2. **ネットワーク品質管理**: パケットドロップやエラー率の可視化
3. **容量管理**: DHCPリース数の監視によりIPアドレス枯渇を防止
4. **自動通知**: 異常時のDiscordアラート通知

これらの機能により、ネットワークの安定運用とトラブルシューティングが
より効率的に行えるようになりました。
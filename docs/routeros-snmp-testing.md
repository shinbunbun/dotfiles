# RouterOS SNMP OID動作確認手順

## 概要
RouterOS SNMP監視用に追加したOIDの動作確認手順を記載します。

## 追加したOID

### 1. システムヘルス関連
- `1.3.6.1.4.1.14988.1.1.13.10` - システム再起動回数
- `1.3.6.1.4.1.14988.1.1.13.11` - 不良ブロック数
- `1.3.6.1.4.1.14988.1.1.13.12` - USB電源リセット回数

### 2. DHCP監視
- `1.3.6.1.4.1.14988.1.1.6.1` - アクティブDHCPリース数

### 3. バージョン管理
- `1.3.6.1.4.1.14988.1.1.4.4` - 現在のRouterOSバージョン
- `1.3.6.1.4.1.14988.1.1.7.7` - 利用可能なアップグレードバージョン

## 動作確認手順

### 1. 設定の適用
```bash
# システム設定の再構築と適用
sudo nixos-rebuild switch --flake .#toplevel-homeMachine
```

### 2. SNMP Exporterの再起動
```bash
# サービスの再起動
sudo systemctl restart snmp-exporter.service

# サービス状態の確認
sudo systemctl status snmp-exporter.service
```

### 3. メトリクスの確認

#### 方法1: SNMP Exporterから直接確認
```bash
# SNMP Exporterのメトリクスエンドポイントにアクセス
curl http://localhost:9116/snmp?target=192.168.1.1 | grep -E "mtxrSystem|mtxrDHCP"
```

#### 方法2: snmpwalkで直接確認
```bash
# システムヘルス関連
snmpwalk -v2c -c prometheus 192.168.1.1 1.3.6.1.4.1.14988.1.1.13

# DHCP情報
snmpwalk -v2c -c prometheus 192.168.1.1 1.3.6.1.4.1.14988.1.1.6

# バージョン情報
snmpwalk -v2c -c prometheus 192.168.1.1 1.3.6.1.4.1.14988.1.1.4.4
snmpwalk -v2c -c prometheus 192.168.1.1 1.3.6.1.4.1.14988.1.1.7.7
```

### 4. Prometheusでの確認
```bash
# Prometheusの管理画面にアクセス
# http://localhost:9090

# 以下のクエリで新しいメトリクスを確認:
# - mtxrSystemRebootCount
# - mtxrSystemBadBlocks
# - mtxrSystemUSBPowerResets
# - mtxrDHCPLeaseCount
# - mtxrSystemCurrentVersion
# - mtxrSystemUpgradeVersion
```

### 5. Grafanaダッシュボードでの確認
1. Grafanaにアクセス（http://localhost:3000）
2. RouterOSダッシュボードを開く
3. 新しいメトリクスを使用したパネルを追加

## 期待される値

### システムヘルス
- **再起動回数**: 0以上の整数値（増加のみ）
- **不良ブロック数**: 0（正常時）
- **USB電源リセット**: 0（正常時）

### DHCP
- **アクティブリース数**: 現在の接続デバイス数（例: 14）

### バージョン
- **現在のバージョン**: "7.19.2"（例）
- **アップグレードバージョン**: "7.19.2"（最新の場合は同じ）

## トラブルシューティング

### メトリクスが取得できない場合
1. SNMP Exporterのログを確認
   ```bash
   journalctl -u snmp-exporter -f
   ```

2. RouterOSのSNMP設定を確認
   ```bash
   # RouterOSにSSH接続して確認
   /snmp print
   /snmp community print
   ```

3. ファイアウォールを確認
   - ポート161/UDPが開いているか確認

### 値が期待と異なる場合
1. OIDの正確性を確認
   ```bash
   snmpwalk -v2c -c prometheus 192.168.1.1 1.3.6.1.4.1.14988 | grep -E "1\.1\.13|1\.1\.6|1\.1\.4\.4|1\.1\.7\.7"
   ```

2. RouterOSの実際の状態と比較
   - RouterOSのWeb UIまたはCLIで実際の値を確認

## 関連ファイル
- SNMP設定: `/home/bunbun/dotfiles/cells/core/nixosProfiles/snmp.yml`
- 推奨OIDリスト: `/home/bunbun/dotfiles/docs/routeros-recommended-oids.md`
- 全OID調査結果: `/home/bunbun/dotfiles/docs/routeros-all-oids-investigation.md`
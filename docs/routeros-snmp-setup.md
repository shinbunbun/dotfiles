# RouterOS SNMP設定手順

## 概要
RouterOSでSNMPv2cを有効化し、Prometheusから監視できるようにする手順です。

## 設定手順

### 1. RouterOSにSSHでログイン
```bash
ssh admin@192.168.1.1
```

### 2. SNMPを有効化
```routeros
/snmp set enabled=yes
```

### 3. SNMPコミュニティ設定
```routeros
/snmp community
add name=prometheus addresses=192.168.1.0/24 read-access=yes write-access=no
```

### 4. SNMP設定の確認
```routeros
/snmp print
/snmp community print
```

## セキュリティ考慮事項
- コミュニティ文字列は推測困難なものを使用
- アクセスを内部ネットワーク（192.168.1.0/24）に制限
- 読み取り専用アクセスのみ許可

## テスト方法
NixOSサーバーから以下のコマンドでテスト：
```bash
snmpwalk -v 2c -c prometheus 192.168.1.1 system
```
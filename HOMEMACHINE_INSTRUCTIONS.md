# homeMachine作業指示書 - Issue #199 Fluent Bit統合とClickHouse廃止

## 概要
nixos-desktop側でFluent BitへのLoki出力追加とClickHouse/Promtail廃止が完了しました。
homeMachine側でも同様の作業を行い、ログ収集をFluent Bitに統一します。

## 前提条件
- nixos-desktop側の作業が完了していること
- mainブランチに最新の変更がマージされていること
- homeMachineでmainブランチからpullしてブランチを作成済みであること

## 実施手順

### Phase 1: homeMachineにFluent Bitを導入

#### 1.1 homeMachine/default.nixの編集
**ファイル**: `systems/nixos/configurations/homeMachine/default.nix`

以下の変更を実施：

```nix
# 削除: promtail.nixインポート（40行目付近）
# 削除前:
#     ../../modules/services/promtail.nix

# 追加: fluent-bit.nixインポート
# サービスモジュールセクションに以下を追加:
    ../../modules/services/fluent-bit.nix
```

**変更内容**:
- `../../modules/services/promtail.nix` の行を削除
- `../../modules/services/fluent-bit.nix` の行を追加（同じサービスモジュールセクション内）

**変更後のimportsセクション例**:
```nix
  imports = [
    # ハードウェア設定
    (if isVM then ../../modules/vm.nix else ./hardware.nix)

    # 基本モジュール
    ../../modules/base.nix
    ../../modules/optimise.nix
    ../../modules/networking.nix
    ../../modules/security.nix
    ../../modules/system-tools.nix
    ../../modules/wireguard.nix
    ../../modules/nfs.nix
    ../../modules/kubernetes.nix

    # サービスモジュール
    ../../modules/services/services.nix
    ../../modules/services/monitoring.nix
    ../../modules/services/alertmanager.nix
    ../../modules/services/loki.nix
    ../../modules/services/fluent-bit.nix  # 追加
    ../../modules/services/authentik.nix
    ../../modules/services/cockpit.nix
    ../../modules/services/ttyd.nix
    ../../modules/services/obsidian-livesync.nix
    ../../modules/services/routeros-backup.nix
    ../../modules/services/unified-cloudflare-tunnel.nix

    # 外部モジュール
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];
```

### Phase 2: 動作確認

#### 2.1 構文チェックとフォーマット
```bash
# flakeチェック
nix flake check

# フォーマット
nix fmt

# homeMachineのビルドチェック（dry-run）
nix build .#nixosConfigurations.homeMachine.config.system.build.toplevel --dry-run
```

#### 2.2 実際のビルド（オプション - ローカルで確認可能な場合）
```bash
# homeMachineのビルド
sudo nixos-rebuild build --flake .#homeMachine
```

### Phase 3: デプロイと動作確認

#### 3.1 システムへの適用
```bash
# homeMachineにデプロイ
sudo nixos-rebuild switch --flake .#homeMachine
```

#### 3.2 サービス状態の確認
```bash
# Fluent Bitサービスの状態確認
sudo systemctl status fluent-bit

# Fluent Bitのログ確認
sudo journalctl -u fluent-bit -f

# Promtailが停止していることを確認
sudo systemctl status promtail
# → 「Unit promtail.service could not be found.」と表示されればOK
```

#### 3.3 ログ収集の確認

**OpenSearchでの確認**:
1. OpenSearch Dashboards (http://192.168.1.4:5601) にアクセス
2. Discover → ログインデックス `logs-*` を選択
3. ホストフィルタ: `host: nixos` または `host.keyword: nixos` で検索
4. homeMachine (nixos) からのログが収集されていることを確認

**Lokiでの確認**:
1. Grafana (http://nixos.shinbunbun.com:3000) にアクセス
2. Explore → Loki データソースを選択
3. ラベルフィルタ: `{host="nixos"}` でクエリ
4. homeMachineからのログがLokiに送信されていることを確認

### Phase 4: リソース確認

#### 4.1 メモリ使用量の確認
```bash
# Fluent Bitのメモリ使用量
sudo systemctl status fluent-bit | grep Memory

# システム全体のメモリ使用量
free -h
```

**期待される効果**:
- Promtail (256MB) が停止
- Fluent Bit (512MB) が起動
- 正味: 約256MBのメモリ増加（軽量化）

### Phase 5: 削除されたサービスの確認

以下のサービスがhomeMachineには影響しないことを確認:
- ClickHouse → nixos-desktopのみで稼働していたため影響なし
- anomaly-detection → nixos-desktopのみで稼働していたため影響なし
- Promtail → 削除済み、Fluent Bitに置き換え

### Phase 6: コミットとプッシュ

```bash
# 変更をステージング
git add systems/nixos/configurations/homeMachine/default.nix

# コミット
git commit -m "feat: homeMachineにFluent Bit統合、Promtail廃止

Issue #199の対応
- homeMachine/default.nixにfluent-bit.nixをインポート
- promtail.nixインポートを削除
- Lokiとの併用体制構築完了

動作確認:
- nix flake check成功
- nix fmt成功
- nix build成功
- Fluent Bitサービス正常起動
- OpenSearchとLokiにログ送信確認

リソース効果:
- Promtail 256MB削減
- Fluent Bit 512MB追加
- 正味256MB増加

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# プッシュ
git push
```

### Phase 7: PR作成

```bash
gh pr create --title "feat: Fluent Bit統合とClickHouse/Promtail廃止 (#199)" --body "$(cat <<'EOF'
## 概要
Issue #199の完全実装: ログ収集をFluent Bitに一本化し、ClickHouse/Promtail/anomaly-detectionを廃止

## 実装内容

### nixos-desktop
- ✅ Fluent BitにLoki出力プラグイン追加
- ✅ Promtailインポート削除
- ✅ ClickHouseとanomaly-detectionインポート削除
- ✅ 関連モジュールファイル削除（clickhouse.nix, anomaly-detection.nix, promtail.nix）
- ✅ config.nixからclickhouse/promtail設定削除
- ✅ anomaly-wall.jsonダッシュボード削除

### homeMachine
- ✅ Fluent Bitインポート追加
- ✅ Promtailインポート削除

## 新しいアーキテクチャ

\`\`\`
systemd-journal (nixos + nixos-desktop)
    └→ Fluent Bit
        ├→ OpenSearch (長期保存・全文検索・詳細分析) [30日保持]
        └→ Loki (短期・リアルタイム監視) [30日保持]
\`\`\`

## 動作確認

### ビルド確認
- [x] nix flake check 成功（nixos-desktop）
- [x] nix fmt 成功
- [x] nix build 成功（両ホスト）

### ログ収集確認
- [x] OpenSearch: 両ホストのログ収集確認
- [x] Loki: 両ホストのログ収集確認
- [x] ホスト別フィルタリング動作確認

### サービス確認
- [x] Fluent Bit正常起動（両ホスト）
- [x] Promtail停止確認
- [x] ClickHouse停止確認
- [x] anomaly-detection停止確認

## リソース削減効果

### nixos-desktop
- Promtail: 256MB削減
- ClickHouse: 4GB削減
- anomaly-detection: 512MB削減
- **合計: 約4.8GB削減**

### homeMachine
- Promtail: 256MB削減
- Fluent Bit: 512MB追加
- **正味: 256MB増加**

### 全体
- **総メモリ削減: 約4.5GB**

## 使い分けガイド

| 用途 | ツール | 理由 |
|------|--------|------|
| **リアルタイム監視** | Grafana + Loki | 軽量・高速、Prometheusと統合 |
| **アラート設定** | Grafana + Loki | Loki Rulerで設定済み |
| **詳細ログ分析** | OpenSearch Dashboards | 全文検索、複雑なフィルタリング |
| **長期保存確認** | OpenSearch Dashboards | 30日間の詳細ログ |
| **トラブルシューティング** | OpenSearch Dashboards | フィールド別絞り込み |

## 関連Issue
- Closes #199

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## トラブルシューティング

### Fluent Bitが起動しない
```bash
# ログを確認
sudo journalctl -u fluent-bit -n 100

# 設定ファイルの確認
sudo cat /nix/store/*-fluent-bit.conf/fluent-bit.conf
```

### Lokiにログが送信されない
```bash
# Lokiサービスの確認
sudo systemctl status loki

# Lokiのログ確認
sudo journalctl -u loki -f

# ネットワーク疎通確認
curl -I http://localhost:3100/ready
```

### OpenSearchにログが送信されない
```bash
# OpenSearchの疎通確認
curl -u admin:admin -I http://192.168.1.4:9200

# Fluent Bitのメトリクス確認
curl http://localhost:2020/api/v1/metrics
```

## 完了条件チェックリスト

- [ ] homeMachine/default.nixからpromtail.nixインポート削除
- [ ] homeMachine/default.nixにfluent-bit.nixインポート追加
- [ ] nix flake check成功
- [ ] nix fmt成功
- [ ] nix build成功（両ホスト）
- [ ] Fluent Bitサービス正常起動
- [ ] OpenSearchで両ホストのログ確認
- [ ] Lokiで両ホストのログ確認
- [ ] Promtailサービスが存在しないことを確認
- [ ] PR作成とマージ

## 参考情報

- Issue: https://github.com/shinbunbun/dotfiles/issues/199
- Fluent Bit設定: `systems/nixos/modules/services/fluent-bit.nix`
- config.nix: `shared/config.nix`

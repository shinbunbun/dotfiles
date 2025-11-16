# shinbunbun's dotfiles

[![Auto Update Flakes (PR Mode)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml)
[![Nix CI](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml)

NixOSとmacOS (Darwin)用の個人dotfiles。標準的なNix flakeを使用して構成されています。

> **Note**: Magic Nix Cacheを使用してCIビルドを高速化しています。

## プロジェクト構造

```
.
├── systems/               # システム設定
│   ├── nixos/            # NixOS設定
│   │   ├── configurations/   # マシン別設定
│   │   │   └── homeMachine/ # NixOSマシン設定
│   │   └── modules/          # NixOSモジュール
│   │       ├── services/     # サービス設定
│   │       │   ├── monitoring.nix    # 監視スタック
│   │       │   ├── dashboards/       # Grafanaダッシュボード
│   │       │   └── ...
│   │       └── ...
│   └── darwin/           # macOS (Darwin)設定
│       ├── configurations/   # マシン別設定
│       └── modules/          # Darwinモジュール
├── home/                  # Home Manager設定
│   ├── profiles/         # ユーザープロファイル
│   │   ├── bunbun/      # bunbunユーザー設定
│   │   └── shinbunbun/  # shinbunbunユーザー設定
│   └── modules/          # Home Managerモジュール
│       ├── development/  # 開発ツール
│       ├── shell/       # シェル関連
│       └── security/    # セキュリティツール
├── shared/               # 共有設定
│   └── config.nix       # 中央設定ファイル
├── devshell/            # 開発環境
│   └── default.nix      # Nix開発シェル
├── secrets/             # SOPS暗号化シークレット
├── terraform/           # Terraform設定
│   └── README.md        # Cloudflare Infrastructure as Code
├── docs/                # ドキュメント
└── flake.nix           # Flakeエントリーポイント
```

## セットアップ

### 前提条件

- Nix 2.4以降（flakesサポート付き）
- SOPS（シークレット管理用）
- Age（暗号化用）

### NixOS

1. Nix flakesを有効化:
   ```bash
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

2. 開発環境に入る:
   ```bash
   nix develop
   ```

   開発環境では以下のツールが利用可能です:
   - **Nix開発ツール**: nix, nixpkgs-fmt, alejandra
   - **SOPS関連**: age, sops, ssh-to-age
   - **Terraform関連**: terraform, terraform-ls, cf-terraforming
   - **Cloudflare環境変数**: SOPSから自動読み込み

3. NixOS設定を適用:
   ```bash
   sudo nixos-rebuild switch --flake .#homeMachine
   ```

### macOS (Darwin)

1. Nix flakesを有効化:
   ```bash
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

2. 開発環境に入る:
   ```bash
   nix develop
   ```

   開発環境では以下のツールが利用可能です:
   - **Nix開発ツール**: nix, nixpkgs-fmt, alejandra
   - **SOPS関連**: age, sops, ssh-to-age
   - **Terraform関連**: terraform, terraform-ls, cf-terraforming

3. Darwin設定を適用:
   ```bash
   darwin-rebuild switch --flake .#macbook
   ```

## 主要なモジュール

### NixOSモジュール (systems/nixos/modules/)
- `base` - 基本的なシステム設定（ブート、Nix設定、ユーザー、NTP）
- `networking` - ネットワーク設定（ファイアウォール、Avahi）
- `security` - セキュリティ設定（PAM、Polkit、SOPS）
- `kubernetes` - Kubernetesツールと設定
- `nfs` - NFSサーバー設定
- `system-tools` - システムツール（polkit、wireguard-tools）
- `wireguard` - WireGuard VPN設定
- `vscode-server` - VS Code Server設定（リモート開発環境）
- **services/** - サービス設定
  - **監視・ログ分析スタック:**
    - `monitoring` - Prometheus、Grafana、Node Exporter監視スタック
    - `alertmanager` - アラート管理とDiscord通知
    - `loki` - ログ集約システム
    - `promtail` - ログ収集エージェント（全ホスト）
    - `clickhouse` - 高速分析データベース
    - `anomaly-detection` - Isolation Forestによる異常検知
  - **バックアップ・同期:**
    - `obsidian-livesync` - Obsidian LiveSync設定
    - `routeros-backup` - RouterOS設定の自動バックアップ
  - **管理・アクセス系:**
    - `cockpit` - Webベースのシステム管理ツール
    - `ttyd` - Webベースのターミナルエミュレータ
    - `authentik` - IdP（Identity Provider）
    - `unified-cloudflare-tunnel` - Cloudflare Tunnel統合設定

### Darwinモジュール (systems/darwin/modules/)
- `base` - macOS基本設定とHomebrew
- `optimise` - Nixストア最適化設定
- `wireguard` - WireGuard VPN設定

### Home Managerモジュール (home/modules/)

#### development/
- `ai-tools` - AIツール（claude-code）
- `cloud-tools` - クラウドツール（Google Cloud SDK）
- `development-tools` - 開発ツール（cocoapods - macOSのみ）
- `editors` - エディタ設定（vim）

#### shell/
- `shell-tools` - シェル関連ツール（zsh、starship、direnv、lsd）
- `version-control` - Git設定

#### security/
- `security-tools` - セキュリティツール（age、sops）

## 監視・ログ分析基盤

このプロジェクトには、包括的な監視とログ分析のインフラが含まれています：

### アーキテクチャ

```
各ホスト → Promtail → Loki(homeMachine) → ClickHouse(nixos-desktop)
                      ↓
                  Grafana(homeMachine) ← ClickHouse(nixos-desktop)
```

### コンポーネント

- **Loki** (homeMachine): ログの集約と短期保存（14-30日）
- **Promtail** (全ホスト): systemd-journaldからのログ収集
- **ClickHouse** (nixos-desktop): 長期保存と高速分析（30-180日）
- **異常検知** (nixos-desktop): 5分ごとのIsolation Forest実行
- **Grafana** (homeMachine): 統合ダッシュボードと可視化

詳細は[ログ分析基盤設計書](docs/log-analyze-plan.md)を参照してください。

## Infrastructure as Code (Terraform)

このプロジェクトでは、CloudflareのインフラをTerraformで管理しています。

### 管理対象

- **DNS Records**: Cloudflare Tunnel向けCNAMEレコード
- **Access Applications**: Cloudflare Access アプリケーション登録

詳細は[Terraform README](terraform/README.md)を参照してください。

### 使用方法

```bash
# 開発シェルに入る（Cloudflare環境変数が自動読み込みされます）
nix develop

# Terraformディレクトリに移動
cd terraform

# 初期化
terraform init

# 変更内容を確認
terraform plan

# 変更を適用
terraform apply
```

## 設定のカスタマイズ

### 中央設定

`shared/config.nix`ファイルで以下の設定を管理:

- ユーザー名とホームディレクトリ
- ネットワーク設定（ホスト名、IPアドレス、ポート）
- SSH設定
- WireGuard VPN設定
- その他のサービス設定

### 新しいマシンの追加

1. `shared/config.nix`に必要な設定を追加
2. `systems/nixos/configurations/`または`systems/darwin/configurations/`に新しいマシン設定ディレクトリを作成
3. `default.nix`ファイルを作成し、必要なモジュールをインポート
4. `flake.nix`のnixosConfigurationsまたはdarwinConfigurationsに新しいマシンを追加

## シークレット管理

このプロジェクトではSOPSとAgeを使用してシークレットを管理しています。

1. Age鍵を生成:
   ```bash
   age-keygen -o ~/.config/sops/age/keys.txt
   ```

2. `.sops.yaml`に公開鍵を追加

3. シークレットを暗号化:
   ```bash
   sops secrets/your-secret.yaml
   ```

## トラブルシューティング

### SOPS復号化エラー

```
age.keyFile = "/var/lib/sops-nix/key.txt";
```

鍵ファイルが正しい場所にあることを確認してください。

### Nix flake check失敗

```bash
nix flake check
```

エラーメッセージを確認し、必要に応じて`nix fmt`を実行してください。

## ライセンス

MIT License
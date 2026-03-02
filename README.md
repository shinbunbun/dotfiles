# shinbunbun's dotfiles

[![Auto Update Flakes (PR Mode)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml)
[![Nix CI](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml)

NixOSとmacOS (Darwin)用の個人dotfiles。標準的なNix flakeを使用して構成されています。

## プロジェクト構造

```
.
├── systems/               # システム設定
│   ├── nixos/            # NixOS設定
│   │   ├── configurations/   # マシン別設定
│   │   │   └── homeMachine/ # NixOSマシン設定
│   │   └── modules/          # NixOSモジュール
│   │       ├── services/     # サービス設定
│   │       │   ├── services.nix  # SSH/Fail2ban/Docker
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
│   └── README.md        # Cloudflare + Authentik Infrastructure as Code
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
   - **Nix開発ツール**: nix, nixfmt-tree, nil, nixd
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
   - **Nix開発ツール**: nix, nixfmt-tree, nil, nixd
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
- `k3s` - k3s（軽量Kubernetes）設定
- `nfs` - NFSサーバー設定
- `system-tools` - システムツール（polkit、wireguard-tools、jq、openssl、python3、gnumake）
- `wireguard` - WireGuard VPN設定
- `vscode-server` - VS Code Server設定（flake inputからの直接インポート）
- **services/** - サービス設定
  - **基盤サービス:**
    - `services` - OpenSSH/Fail2ban/Docker基盤
    - `deploy-user` - deploy-rsデプロイユーザー
    - `mosh` - Mosh（Mobile Shell）
  - **バックアップ・同期:**
    - `obsidian-livesync` - Obsidian LiveSync設定
    - `routeros-backup` - RouterOS設定の自動バックアップ
  - **管理・アクセス系:**
    - `cockpit` - Webベースのシステム管理ツール
    - `ttyd` - Webベースのターミナルエミュレータ
    - `authentik` - IdP（Identity Provider）
    - `unified-cloudflare-tunnel` - Cloudflare Tunnel統合設定
    - `desktop-cloudflare-tunnel` - デスクトップ向けCloudflare Tunnel
  - **インフラ:**
    - `attic` - Attic Nixバイナリキャッシュ
    - `peer-issuer` - WireGuard peer動的発行API
    - `argocd` - ArgoCD設定

> **Note**: 監視・ログ分析スタック（Prometheus、Grafana、Loki、Fluent Bit等）は[nixos-observability](https://github.com/shinbunbun/nixos-observability)/[nixos-observability-config](https://github.com/shinbunbun/nixos-observability-config)に移行しています。

### Darwinモジュール (systems/darwin/modules/)
- `base` - macOS基本設定とHomebrew
- `optimise` - Nixストア最適化設定
- `wireguard` - WireGuard VPN設定
- `node-exporter` - Prometheus Node Exporter
- `fluent-bit` - Fluent Bitログ収集

### Home Managerモジュール (home/modules/)

#### development/
- `ai-tools` - AIツール（claude-code）
- `cloud-tools` - クラウドツール（Google Cloud SDK）
- `development-tools` - 開発ツール（cocoapods - macOSのみ）
- `editors` - エディタ設定（vim）

#### shell/
- `shell-tools` - シェル関連ツール（zsh、starship、direnv、lsd）
- `tmux` - tmux端末多重化
- `version-control` - Git設定

#### security/
- `security-tools` - セキュリティツール（age、sops）

## 監視・ログ分析基盤

監視・ログ分析基盤は [nixos-observability](https://github.com/shinbunbun/nixos-observability) / [nixos-observability-config](https://github.com/shinbunbun/nixos-observability-config) で管理されており、本リポジトリからflake inputとして参照しています。

### アーキテクチャ

```
各ホスト → Fluent Bit → Loki(homeMachine) → Grafana(homeMachine)
                        ↑
              Prometheus(homeMachine) ← Node Exporter（各ホスト）
```

### コンポーネント

- **Loki** (homeMachine): ログの集約と保存
- **Fluent Bit** (全ホスト): ログ収集エージェント（systemd-journal、macOS Unified Log）
- **Prometheus** (homeMachine): メトリクス収集
- **Node Exporter** (全ホスト): ホストメトリクスの公開
- **Grafana** (homeMachine): 統合ダッシュボードと可視化

## Infrastructure as Code (Terraform)

このプロジェクトでは、CloudflareおよびAuthentikのインフラをTerraformで管理しています。

### 管理対象

- **DNS Records**: Cloudflare Tunnel向けCNAMEレコード
- **Access Applications**: Cloudflare Access アプリケーション登録
- **Authentik**: OAuth2/Proxyプロバイダー、アプリケーション登録、ユーザー・グループ管理、認可ポリシー・バインディング、アウトポスト設定

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
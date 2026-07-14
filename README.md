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
│   │   │   ├── homeMachine/ # NixOSマシン設定
│   │   │   └── g3pro/       # NixOSマシン設定 (deploy-rs対象)
│   │   └── modules/          # NixOSモジュール
│   │       ├── services/     # サービス設定
│   │       │   ├── services.nix  # SSH/Fail2ban/Docker
│   │       │   └── ...
│   │       └── ...
│   └── darwin/           # macOS (Darwin)設定
│       ├── configurations/   # マシン別設定
│       │   ├── macbook/     # MacBook設定
│       │   └── macmini/     # Mac mini設定
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

3. Darwin設定を適用:
   ```bash
   darwin-rebuild switch --flake .#macbook
   ```

## 主要なモジュール

### NixOSモジュール (systems/nixos/modules/)

`flake.nix` の `nixosModules` export と対応します。

- `base` - 基本的なシステム設定（ブート、Nix設定、ユーザー、NTP）
- `desktop` - デスクトップ環境設定（X/GNOME、オーディオ、グラフィックス）
- `security` - セキュリティ設定（PAM、Polkit、SOPS）
- `optimise` - Nixストア自動最適化・ガベージコレクション
- `system-tools` - システムツール（polkit、wireguard-tools、jq、openssl、python3、gnumake）
- `networking` - ネットワーク設定（ファイアウォール、Avahi）
- `wireguard` - WireGuard VPN設定
- `nfs` - NFSサーバー設定
- `k3s` - k3s（軽量Kubernetes）設定
- `vm` - VMビルド用基本設定（CI/テスト環境）
- **services/** - サービス設定
  - **基盤サービス:**
    - `services` - OpenSSH/Fail2ban/Docker基盤
    - `deploy-user` - deploy-rsデプロイユーザー
    - `mosh` - Mosh（Mobile Shell）
  - **ストレージ・メディア:**
    - `samba` - SMBファイル共有サーバー（NAS）
    - `jellyfin` - メディアサーバー
    - `nextcloud` - Nextcloud（ファイル同期・共有）
    - `immich` - Immich（写真・動画管理）
  - **管理・アクセス系:**
    - `cockpit` - Webベースのシステム管理ツール
    - `unified-cloudflare-tunnel` - Cloudflare Tunnel統合設定
    - `desktop-cloudflare-tunnel` - デスクトップ向けCloudflare Tunnel
    - `argocd` - ArgoCD（GitOps）設定
  - **インフラ:**
    - `attic` - Attic Nixバイナリキャッシュ
    - `llamaCpp` - llama.cpp OpenAI互換 LLM 推論サーバー
    - `disk-monitoring` - ディスク SMART 監視（smartd / smartctl_exporter）

> **Note**: `vscode-server` は `nixosModules` export ではなく、flake input から各ホスト設定で直接 import しています。

> **Note**: 監視・ログ分析基盤のうち、収集エージェント（Fluent Bit / 各 exporter）の設定モジュールは[nixos-observability](https://github.com/shinbunbun/nixos-observability)/[nixos-observability-config](https://github.com/shinbunbun/nixos-observability-config)から flake input として参照しています。集約・保存側（Loki / VictoriaMetrics スタック / Alertmanager）と可視化（Grafana）は [k8s-apps](https://github.com/shinbunbun/k8s-apps) で k3s 上にホストされています。詳細は下記「監視・ログ分析基盤」を参照。

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

エージェント側（Fluent Bit / Node Exporter / Process Exporter / smartctl Exporter）を NixOS 各ホストで動かし、その設定モジュールは [nixos-observability](https://github.com/shinbunbun/nixos-observability) / [nixos-observability-config](https://github.com/shinbunbun/nixos-observability-config) を flake input として参照しています。集約・保存側（Loki / VictoriaMetrics スタック / vmagent / Alertmanager）と可視化（Grafana）は [k8s-apps](https://github.com/shinbunbun/k8s-apps) 配下で k3s 上にホストされ、Cilium LB IPAM の固定 LAN VIP 経由でアクセスします。

### アーキテクチャ

```
各ホスト → Fluent Bit ──────────→ Loki (k3s VIP) ─┐
                                                   ├─→ Grafana(k3s)
        Node Exporter ← vmagent (k3s) → VictoriaMetrics(k3s) ─┘
        （各ホスト）
```

### コンポーネント

- **Fluent Bit** (全ホスト): ログ収集エージェント（systemd-journal、macOS Unified Log）→ k3s 上の Loki VIP へ転送
- **Loki** (k3s クラスタ): ログの集約と保存（k8s-apps/infrastructure/loki、LAN VIP `192.168.128.14`）
- **Node Exporter / Process Exporter / smartctl Exporter** (各ホスト): ホスト・プロセス・ディスクメトリクスの公開
- **vmagent / VictoriaMetrics** (k3s クラスタ): 各ホストの exporter をスクレイプしメトリクスを集約・保存
- **Grafana** (k3s クラスタ): 統合ダッシュボードと可視化（k8s-apps/infrastructure/grafana）

## Infrastructure as Code (Terraform)

CloudflareおよびAuthentikのインフラ定義（DNS / Cloudflare Access / Authentik OIDC
プロバイダー・アプリケーション・グループ等）は、セルフホスト Terrakube + プライベート
リポジトリ `homelab-iac` の `stacks/cloudflare` / `stacks/authentik` へ移行しました
（dotfiles-private#327 Phase 4）。`git push → webhook → Terrakube run` で適用されます。

機密値（API トークン / OAuth client secret 等）は引き続き `secrets/` の SOPS
暗号化ファイルが source of truth で、同じ値を Terrakube の workspace 変数にも投入
しています（E1 方針）。このリポジトリでローカル `terraform` 実行は行いません。

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

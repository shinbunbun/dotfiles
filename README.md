# shinbunbun's dotfiles

[![Auto Update Flakes (PR Mode)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/auto-update-flake.yaml)
[![Nix CI](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/ci.yaml)
[![std CI(macOS)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-macos.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-macos.yaml)
[![std CI(NixOS)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-nixos.yaml/badge.svg)](https://github.com/shinbunbun/dotfiles/actions/workflows/std-nixos.yaml)

NixOSとmacOS (Darwin)用の個人dotfiles。[std-hive](https://github.com/divnix/hive)フレームワークを使用して構成されています。

## プロジェクト構造

```
.
├── cells/                  # std-hiveのセル（モジュール）
│   ├── core/              # コアシステム設定
│   │   ├── config.nix     # 中央設定ファイル（ユーザー、ネットワーク、サービス）
│   │   ├── homeProfiles/  # Home Manager プロファイル
│   │   ├── nixosProfiles/ # NixOS システムプロファイル
│   │   │   ├── dashboards/    # Grafanaダッシュボード定義
│   │   │   ├── alertmanager.nix    # アラート設定
│   │   │   ├── monitoring.nix      # 監視スタック設定
│   │   │   └── ...
│   │   └── darwinProfiles.nix # macOS (Darwin) プロファイル
│   ├── dev/               # 開発環境設定
│   │   └── homeProfiles/  # 開発ツール用Home Managerプロファイル
│   ├── repo/              # リポジトリ関連
│   │   └── shells.nix     # Nix開発シェル
│   ├── shinbunbun/        # 個人設定
│   └── toplevel/          # トップレベル設定
│       ├── nixosConfigurations.nix  # NixOSマシン設定
│       └── darwinConfigurations.nix # macOSマシン設定
├── docs/                  # ドキュメント
│   ├── monitoring-implementation-plan.md  # 監視システム実装計画
│   ├── monitoring-alerts-summary.md       # アラート設定まとめ
│   └── ...
├── secrets/               # SOPS暗号化シークレット
└── flake.nix             # Flakeエントリーポイント
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

3. Darwin設定を適用:
   ```bash
   std //toplevel/darwinConfigurations/macOS:switch
   ```

## 主要なプロファイル

### Core Profiles

#### nixosProfiles
- `base` - 基本的なシステム設定（ブート、Nix設定、ユーザー、NTP）
- `networking` - ネットワーク設定（ファイアウォール、Avahi）
- `services` - サービス設定（SSH、Docker、Fail2ban）
- `security` - セキュリティ設定（PAM、Polkit、SOPS）
- `kubernetes` - Kubernetesツールと設定
- `nfs` - NFSサーバー設定
- `system-tools` - システムツール（polkit、wireguard-tools）
- `obsidian-livesync` - Obsidian LiveSync設定
- `monitoring` - Prometheus、Grafana、Node Exporter監視スタック
- `alertmanager` - アラート管理とDiscord通知
- `routeros-backup` - RouterOS設定の自動バックアップ
- `wireguard` - WireGuard VPN設定

#### darwinProfiles
- `default` - macOS基本設定とHomebrew
- `optimize` - Nixストア最適化設定
- `wireguard` - WireGuard VPN設定

### Dev Profiles (Home Manager)

- `versionControl` - Git設定
- `shellTools` - シェル関連ツール（zsh、starship、direnv、lsd）
- `editors` - エディタ設定（vim）
- `cloudTools` - クラウドツール（Google Cloud SDK）
- `securityTools` - セキュリティツール（age、sops）
- `developmentTools` - 開発ツール（cocoapods）
- `aiTools` - AIツール（claude-code）

## 設定のカスタマイズ

### 中央設定

`cells/core/config.nix`ファイルで以下の設定を管理:

- ユーザー名とホームディレクトリ
- ネットワーク設定（ホスト名、IPアドレス、ポート）
- SSH設定
- WireGuard VPN設定
- その他のサービス設定

### 新しいマシンの追加

1. `cells/core/config.nix`に必要な設定を追加
2. `cells/toplevel/nixosConfigurations.nix`または`darwinConfigurations.nix`に新しいマシン設定を追加
3. 必要なプロファイルをインポート

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
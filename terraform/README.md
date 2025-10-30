# Cloudflare Terraform設定

このディレクトリには、CloudflareのDNSレコードとAccess PolicyをTerraformで管理するための設定が含まれています。

## 概要

### 管理対象

- **Access Application**: Cloudflare Access アプリケーション登録
- **Access Policy**: OIDC claim認証ポリシー
  - Terraform CloudFlare Provider v5で`cloudflare_zero_trust_access_policy`リソースのOIDC claim対応が実装されたため、Terraformで管理
  - 全アプリケーションで共有の認証ポリシーを使用
- **DNS Records**: トンネルに関連するDNSレコード(CNAMEレコード)

### 管理対象外 (NixOSで管理)

- **Cloudflare Tunnel**: トンネル本体の作成と管理
- **Tunnel Ingress設定**: 各サービスへのルーティング設定
- **cloudflared デーモン**: トンネルの起動と管理

## 前提条件

### 必要な環境変数

#### 方法1: SOPS で管理（推奨）

このプロジェクトでは、機密情報をSOPSで暗号化して管理しています。`nix develop`で開発シェルに入ると、自動的に`secrets/cloudflare.yaml`から環境変数が読み込まれます。

```bash
# secrets/cloudflare.yaml に以下を追加（SOPSで暗号化）
cloudflare:
  api-token: "your-api-token"
  zone-id: "your-zone-id"
  account-id: "your-account-id"
  tunnel-id: "home-services-tunnel-id"
  desktop-tunnel-id: "desktop-services-tunnel-id"
  identity-provider-id: "your-idp-id"
  r2-access-key-id: "your-r2-access-key-id"
  r2-secret-access-key: "your-r2-secret-access-key"
```

編集方法:
```bash
# SOPSエディタで編集
sops secrets/cloudflare.yaml
```

開発シェルに入ると自動的に以下の環境変数が設定されます:
- `CLOUDFLARE_API_TOKEN` (cf-terraforming用)
- `TF_VAR_cloudflare_api_token` (Terraform用)
- `TF_VAR_cloudflare_zone_id`
- `TF_VAR_cloudflare_account_id`
- `TF_VAR_home_tunnel_id`
- `TF_VAR_desktop_tunnel_id`
- `TF_VAR_identity_provider_id`
- `AWS_ACCESS_KEY_ID` (Terraform R2バックエンド用)
- `AWS_SECRET_ACCESS_KEY` (Terraform R2バックエンド用)

## 使用方法

### 初回セットアップ

1. **シークレットの設定**（初回のみ）:
   ```bash
   # SOPSでCloudflare設定を追加
   sops secrets/cloudflare.yaml
   # api-token, zone-id, account-id等を追加
   ```

2. **開発シェルに入る**:
   ```bash
   nix develop
   # SOPSから環境変数が自動的に読み込まれます
   ```

3. **環境変数の確認**（オプション）:
   ```bash
   echo $CLOUDFLARE_API_TOKEN
   echo $TF_VAR_cloudflare_zone_id
   # 正しく読み込まれていることを確認
   ```

4. **terraformディレクトリに移動**:
   ```bash
   cd terraform
   ```

5. **Terraformを初期化**:
   ```bash
   terraform init
   ```

### 日常的な運用

1. **変更内容を確認**:
   ```bash
   terraform plan
   ```

2. **変更を適用**:
   ```bash
   terraform apply
   ```

3. **特定のリソースのみを対象にする** (オプション):
   ```bash
   # DNSレコードのみ
   terraform plan -target=cloudflare_record.grafana
   terraform apply -target=cloudflare_record.grafana
   ```

### 設定の削除

リソースを削除する場合:

```bash
terraform destroy
```

**警告**: このコマンドは、Terraform管理下の全てのDNSレコードとAccess設定を削除します。実行前に必ず`terraform plan -destroy`で確認してください。

## ファイル構成

```
terraform/
├── versions.tf              # Terraformとプロバイダーのバージョン指定
├── backend.tf               # R2バックエンド設定
├── main.tf                  # プロバイダー設定とローカル変数
├── variables.tf             # 変数定義
├── access_policies.tf       # Access ApplicationとPolicyの定義
├── dns_records.tf           # DNSレコードの定義
├── outputs.tf               # 出力変数の定義
├── .gitignore               # Git除外設定
└── README.md                # このファイル
```

## 管理対象のサービス

### home-services (homeMachine)

| サービス | DNS | Access App | 備考 |
|---------|-----|-----------|------|
| Authentik | ✓ | - | IdP (認証不要) |
| Grafana | ✓ | ✓ | OIDC認証 |
| Obsidian LiveSync | ✓ | - | 直接認証 |
| Cockpit | ✓ | ✓ | OIDC認証 |
| ttyd | ✓ | ✓ | OIDC認証 |

### desktop-services (nixos-desktop)

| サービス | DNS | Access App | 備考 |
|---------|-----|-----------|------|
| Cockpit | ✓ | ✓ | OIDC認証 |
| ttyd | ✓ | ✓ | OIDC認証 |
| OpenSearch Dashboards | ✓ | ✓ | OIDC認証 |

## State管理

Terraform stateはCloudflare R2 (S3互換ストレージ)にリモート保存されています(`backend.tf`)。

**必要な環境変数**:
- `AWS_ACCESS_KEY_ID`: R2 Access Key ID
- `AWS_SECRET_ACCESS_KEY`: R2 Secret Access Key

これらは`nix develop`で自動的にSOPSから読み込まれます。

## 参考資料

- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Cloudflare Zero Trust Access Documentation](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

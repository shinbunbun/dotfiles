# Cloudflare Zero Trust と Authentik の統合手順

## 1. Authentik側の設定

### OIDCプロバイダー作成

1. **Applications** → **Providers** → **Create** → **OAuth2/OpenID Provider**

2. 以下の設定を入力：
   ```
   Name: Cloudflare Zero Trust
   Authentication flow: default-authentication-flow
   Authorization flow: default-provider-authorization-implicit-consent
   
   Protocol settings:
   - Client type: Confidential
   - Client ID: (自動生成されるので記録)
   - Client Secret: (自動生成されるので記録)
   - Redirect URIs: https://shinbunbun.cloudflareaccess.com/cdn-cgi/access/callback
   
   Scopes:
   - openid
   - email
   - profile
   
   Subject mode: Based on the User's hashed ID
   Include claims in id_token: ✓
   ```

3. **Create** をクリック

### アプリケーション作成

1. **Applications** → **Create**
2. 設定：
   ```
   Name: Cloudflare Zero Trust
   Slug: cloudflare-zero-trust
   Provider: 上記で作成したプロバイダーを選択
   ```

## 2. Cloudflare Zero Trust側の設定

### Identity Provider追加

1. [https://one.dash.cloudflare.com](https://one.dash.cloudflare.com) にアクセス
2. **Settings** → **Authentication** → **Login methods** → **Add new**
3. **OpenID Connect** を選択
4. 以下を設定：
   ```
   Name: Authentik
   App ID: (AuthentikのClient ID)
   Client secret: (AuthentikのClient Secret)
   Auth URL: https://auth.shinbunbun.com/application/o/authorize/
   Token URL: https://auth.shinbunbun.com/application/o/token/
   Certificate URL: https://auth.shinbunbun.com/application/o/cloudflare-zero-trust/jwks/
   Proof Key for Code Exchange (PKCE): Enabled（推奨）
   ```

### Access Applications作成

各サービスごとにアプリケーションを作成：

#### Cockpit
1. **Access** → **Applications** → **Add an application**
2. **Self-hosted** を選択
3. 設定：
   ```
   Application name: Cockpit
   Session duration: 24 hours
   Application domain: cockpit.shinbunbun.com
   Identity providers: Authentik
   ```

#### ttyd Terminal
1. 同様の手順で作成
2. 設定：
   ```
   Application name: Terminal
   Application domain: terminal.shinbunbun.com
   ```

#### Grafana
1. 同様の手順で作成
2. 設定：
   ```
   Application name: Grafana
   Application domain: grafana.shinbunbun.com
   ```

#### Obsidian LiveSync
1. 同様の手順で作成
2. 設定：
   ```
   Application name: Obsidian LiveSync
   Application domain: private-obsidian.shinbunbun.com
   ```

## 3. アクセスポリシー設定

各アプリケーションにポリシーを追加：

### 基本的なメールベースのポリシー例
```
Rule type: Include
Selector: Emails
Value: admin@shinbunbun.com
```

### グループベースのポリシー（Authentikでグループマッピングを設定した場合）
```
Rule type: Include
Selector: External Evaluation
Endpoint URL: https://auth.shinbunbun.com/api/v3/...
```

## 4. 認証情報の保存

生成されたClient IDとClient Secretは、必要に応じてSOPSで暗号化して保存：

```bash
# secrets/authentik.yaml に追加
sops secrets/authentik.yaml

# 以下を追加
cloudflare:
  oidc_client_id: "生成されたClient ID"
  oidc_client_secret: "生成されたClient Secret"
```

## 5. テスト手順

1. 各サービスのURLにアクセス
2. Cloudflareのログインページにリダイレクトされることを確認
3. "Login with Authentik" を選択
4. Authentikでログイン
5. サービスにアクセスできることを確認

## トラブルシューティング

### よくある問題

1. **リダイレクトエラー**
   - Redirect URIが正確に一致しているか確認
   - HTTPSが正しく設定されているか確認

2. **認証エラー**
   - Client ID/Secretが正しいか確認
   - URLが正しいか確認（特に末尾の/）

3. **証明書エラー**
   - JWKSエンドポイントがアクセス可能か確認
   - Authentikが正しく動作しているか確認

## 参考リンク

- [Cloudflare Zero Trust Docs](https://developers.cloudflare.com/cloudflare-one/)
- [Authentik Docs](https://goauthentik.io/docs/)
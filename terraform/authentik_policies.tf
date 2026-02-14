/*
  Authentik カスタムポリシー定義

  カスタムポリシーを管理する。
  デフォルトポリシー（default-*）はBlueprint管理のためTerraformで管理しない。
*/

# GitHub Actions OIDCトークンを検証するポリシー
# wg-leaseアプリケーションへのアクセスを許可されたリポジトリのみに制限
resource "authentik_policy_expression" "wg_lease_allow_github" {
  name              = "wg-lease-allow-github"
  execution_logging = true
  expression        = <<-EOT
    jwt = request.context.get("oauth_jwt")
    if not jwt:
        return False

    if jwt.get("iss") != "https://token.actions.githubusercontent.com":
        return False

    aud = jwt.get("aud")
    if isinstance(aud, list):
        if "wg-lease" not in aud:
            return False
    else:
        if aud != "wg-lease":
            return False

    allowed_repos = {
        "shinbunbun/dotfiles",
        "shinbunbun/dotfiles-private"
    }
    if jwt.get("repository") not in allowed_repos:
        return False

    return True
  EOT
}

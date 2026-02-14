/*
  Authentik 認証ソース定義

  GitHub Actions OIDC Federation用のOAuthソースを管理する。
  wg-lease-proxyのJWKSソースとして使用される。
*/

resource "authentik_source_oauth" "github_actions_oidc" {
  name                = "github-actions-oidc"
  slug                = "github-actions-oidc"
  enabled             = true
  authentication_flow = data.authentik_flow.default_source_authentication.id
  enrollment_flow     = data.authentik_flow.default_source_enrollment.id
  provider_type       = "openidconnect"
  consumer_key        = "unused"
  consumer_secret     = "unused"
  user_matching_mode  = "identifier"
  policy_engine_mode  = "any"
  oidc_well_known_url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
  oidc_jwks_url       = "https://token.actions.githubusercontent.com/.well-known/jwks"
  lifecycle {
    ignore_changes = [authorization_code_auth_method, pkce]
  }
}

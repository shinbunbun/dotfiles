/*
  Authentik デフォルトリソース参照（data sources）

  Blueprint管理のデフォルトリソースをdata sourceとして参照する。
  managedフィールドが goauthentik.io/* のリソースはTerraformで管理せず、
  参照のみ行う。
*/

# --- デフォルトOAuth2スコープマッピング ---
data "authentik_property_mapping_provider_scope" "openid" {
  managed = "goauthentik.io/providers/oauth2/scope-openid"
}

data "authentik_property_mapping_provider_scope" "email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

data "authentik_property_mapping_provider_scope" "profile" {
  managed = "goauthentik.io/providers/oauth2/scope-profile"
}

data "authentik_property_mapping_provider_scope" "proxy" {
  managed = "goauthentik.io/providers/proxy/scope-proxy"
}

# --- デフォルト署名証明書 ---
data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}

data "authentik_certificate_key_pair" "es256_jwt_signing" {
  name = "es256-jwt-signing"
}

# --- デフォルトフロー ---
data "authentik_flow" "default_authorization_explicit_consent" {
  slug = "default-provider-authorization-explicit-consent"
}

data "authentik_flow" "default_authorization_implicit_consent" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_provider_invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_flow" "default_source_authentication" {
  slug = "default-source-authentication"
}

data "authentik_flow" "default_source_enrollment" {
  slug = "default-source-enrollment"
}

# --- デフォルトグループ ---
data "authentik_group" "admins" {
  name = "authentik Admins"
}

# --- Embedded Outpost ---
data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

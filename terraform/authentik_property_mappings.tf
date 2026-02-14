/*
  Authentik カスタムProperty Mappings

  カスタムスコープマッピングを管理する。
  デフォルト（managed="goauthentik.io/*"）はauthentik_data.tfでdata source参照。
*/

resource "authentik_property_mapping_provider_scope" "oidc_groups" {
  name       = "OIDC Groups"
  scope_name = "groups"
  expression = <<-EOT
    return {"groups": [group.name for group in user.ak_groups.all()]}
  EOT
}

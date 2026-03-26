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

# Nextcloud用: "Nextcloud Admins" → "admin" に変換し、Nextcloud組み込みadminグループと一致させる
resource "authentik_property_mapping_provider_scope" "nextcloud_groups" {
  name       = "Nextcloud Groups"
  scope_name = "groups"
  expression = <<-EOT
    group_mapping = {
        "Nextcloud Admins": "admin",
    }
    return {"groups": [group_mapping.get(group.name, group.name) for group in user.ak_groups.all()]}
  EOT
}

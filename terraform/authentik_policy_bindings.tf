/*
  Authentik カスタムポリシーバインディング定義

  アプリケーションへのアクセス制御バインディングを管理する。
  デフォルトバインディング（Blueprint管理）はTerraformで管理しない。
*/

# wg-lease: GitHub Actions OIDCポリシーバインディング
resource "authentik_policy_binding" "wg_lease_allow_github" {
  target = authentik_application.wg_lease.uuid
  policy = authentik_policy_expression.wg_lease_allow_github.id
  order  = 0
}

# CouchDB: akadminユーザーのアクセス許可
resource "authentik_policy_binding" "couchdb_akadmin" {
  target = authentik_application.couchdb.uuid
  user   = data.authentik_user.akadmin.pk
  order  = 0
}

# CouchDB: Obsidian Usersグループのアクセス許可
resource "authentik_policy_binding" "couchdb_obsidian_users" {
  target = authentik_application.couchdb.uuid
  group  = authentik_group.obsidian_users.id
  order  = 0
}

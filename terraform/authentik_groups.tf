/*
  Authentik グループ定義

  カスタムグループを管理する。
  デフォルトグループ（authentik Admins等）はauthentik_data.tfでdata source参照。
*/

resource "authentik_group" "cloudflare_access" {
  name         = "Cloudflare Access"
  is_superuser = false
  users        = [authentik_user.hina.id]
}

resource "authentik_group" "obsidian_users" {
  name         = "Obsidian Users"
  is_superuser = false
}

resource "authentik_group" "argocd_admins" {
  name         = "ArgoCD Admins"
  is_superuser = false
  users        = [data.authentik_user.shinbunbun.id]
}

resource "authentik_group" "argocd_users" {
  name         = "ArgoCD Users"
  is_superuser = false
  users        = [authentik_user.hina.id]
}

resource "authentik_group" "grafana_admins" {
  name         = "Grafana Admins"
  is_superuser = false
  users        = [data.authentik_user.shinbunbun.id]
}

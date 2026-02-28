/*
  Authentik ユーザー定義

  Terraformで管理するユーザーを定義する。
  手動作成済みのユーザー（akadmin, shinbunbun）はauthentik_data.tfでdata source参照。
*/

resource "authentik_user" "hina" {
  username = "hina"
  name     = "hina"
}

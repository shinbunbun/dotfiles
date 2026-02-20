/*
  Authentik Outpost プロバイダー割り当て

  Embedded OutpostへのProxy Providerの割り当てを管理する。
  Outpost自体はBlueprint管理（goauthentik.io/outposts/embedded）のため
  data sourceで参照し、プロバイダーの紐付けのみTerraformで管理する。
*/

resource "authentik_outpost_provider_attachment" "embedded_wg_lease" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.wg_lease.id
}

# secrets/

SOPS (age) で暗号化した secret を格納する。復号鍵は `.sops.yaml` の
`creation_rules` (`secrets/.*`) で管理し、各ホストの age 公開鍵で暗号化される。

## 分類

このディレクトリのファイルは 2 系統に分かれる。**「nix から参照ゼロ」＝孤児とは限らない**
点に注意すること。

### 1. nix から参照されている secret

NixOS / darwin の各設定 (`sops.secrets.*` の `sopsFile`) や CI から直接消費される。
`git grep '<name>.yaml'` で参照箇所を確認できる。

### 2. Terrakube E1 正本 (nix 参照なしは意図的)

Terrakube の workspace 変数へ同値を投入する際の **平文の正本 (source of truth)**。
homelab-iac の Terraform provider が使う値で、nix からは一切参照されない。
**参照ゼロを理由に削除してはならない。**

| ファイル | 役割 |
|---|---|
| `authentik.yaml` | Authentik provider (IdP: provider/application/group 等) |
| `authentik-terraform.yaml` | Authentik Terraform 用トークン |
| `authentik-tunnel.yaml` | Authentik ⇔ Cloudflare Tunnel 連携 |
| `authentik-cloudflare-oidc.yaml` | Cloudflare Zero Trust Access の OIDC 連携 |
| `grafana.yaml` | Grafana provider / datasource 用 |

> `cloudflare.yaml` は Terrakube 正本であると同時に nix からも参照される (系統 1 兼 2)。

## 孤児判定の手順

新たに「未参照だから消してよいか」を判断する場合:

1. `git grep '<name>.yaml' -- ':!secrets/*' ':!.sops.yaml'` で nix / CI 参照を確認。
2. 参照ゼロでも、上表の Terrakube E1 正本に該当しないことを確認。
3. 両方を満たす場合のみ孤児。`git rm` しても暗号化済みで履歴に残るため復元可能。

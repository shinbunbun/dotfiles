/*
  開発シェル設定

  このファイルは開発環境を定義します。
  必要なツールやスクリプトを提供します。
*/
{ pkgs, inputs, ... }:

pkgs.mkShell {
  name = "nix-dotfiles-dev";

  buildInputs =
    with pkgs;
    [
      # Nix開発ツール
      nixfmt-tree
      nil
      nixd

      # SOPSツール
      age
      sops
      ssh-to-age

      # 一般的な開発ツール
      git
      gh
      jq
      yq

      # Terraformツール
      terraform
      terraform-ls
      cf-terraforming

      # Darwin固有のツール
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
      inputs.nix-darwin.packages.${pkgs.system}.default
    ];

  shellHook = ''
    echo "=== Nix Dotfiles Development Shell ==="
    echo "Available commands:"
    echo "  - nixos-rebuild switch --flake .#homeMachine"
    echo "  - darwin-rebuild switch --flake .#macbook"
    echo "  - nix fmt"
    echo "  - nix flake check"
    echo "  - nix build"
    echo ""
    echo "SOPS tools available: age, sops, ssh-to-age"
    echo ""

    # SOPSからCloudflare設定を環境変数に読み込む
    if [ -f secrets/cloudflare.yaml ]; then
      echo "Loading Cloudflare secrets from SOPS..."

      # APIトークン (cf-terraforming用とTerraform用)
      export CLOUDFLARE_API_TOKEN=$(sops -d --extract '["cloudflare"]["api-token"]' secrets/cloudflare.yaml 2>/dev/null)
      export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"

      # R2アクセスキー
      export AWS_ACCESS_KEY_ID=$(sops -d --extract '["cloudflare"]["r2-access-key-id"]' secrets/cloudflare.yaml 2>/dev/null)
      export AWS_SECRET_ACCESS_KEY=$(sops -d --extract '["cloudflare"]["r2-secret-access-key"]' secrets/cloudflare.yaml 2>/dev/null)

      # その他のTerraform変数
      export TF_VAR_cloudflare_zone_id=$(sops -d --extract '["cloudflare"]["zone-id"]' secrets/cloudflare.yaml 2>/dev/null)
      export TF_VAR_cloudflare_account_id=$(sops -d --extract '["cloudflare"]["account-id"]' secrets/cloudflare.yaml 2>/dev/null)
      export TF_VAR_home_tunnel_id=$(sops -d --extract '["cloudflare"]["tunnel-id"]' secrets/cloudflare.yaml 2>/dev/null)
      export TF_VAR_desktop_tunnel_id=$(sops -d --extract '["cloudflare"]["desktop-tunnel-id"]' secrets/cloudflare.yaml 2>/dev/null)
      export TF_VAR_identity_provider_id=$(sops -d --extract '["cloudflare"]["identity-provider-id"]' secrets/cloudflare.yaml 2>/dev/null)

      if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        echo "✓ Cloudflare environment variables loaded from SOPS"
      else
        echo "⚠ Warning: Could not load Cloudflare secrets from SOPS"
        echo "  Make sure you have the correct age key configured"
      fi
    else
      echo "⚠ Warning: secrets/cloudflare.yaml not found"
    fi
    echo ""

    # SOPSからAuthentik設定を環境変数に読み込む
    if [ -f secrets/authentik-terraform.yaml ]; then
      export TF_VAR_authentik_api_token=$(sops -d --extract '["authentik"]["api-token"]' secrets/authentik-terraform.yaml 2>/dev/null)
      [ -n "$TF_VAR_authentik_api_token" ] && echo "✓ Authentik API token loaded"
    fi

    # Grafana OAuth (secrets/grafana.yaml)
    if [ -f secrets/grafana.yaml ]; then
      export TF_VAR_grafana_oauth_client_id=$(sops -d --extract '["grafana"]["oauth_client_id"]' secrets/grafana.yaml 2>/dev/null)
      export TF_VAR_grafana_oauth_client_secret=$(sops -d --extract '["grafana"]["oauth_client_secret"]' secrets/grafana.yaml 2>/dev/null)
      [ -n "$TF_VAR_grafana_oauth_client_id" ] && echo "✓ Grafana OAuth secrets loaded"
    fi

    # Cloudflare OIDC (secrets/authentik-cloudflare-oidc.yaml)
    if [ -f secrets/authentik-cloudflare-oidc.yaml ]; then
      export TF_VAR_cloudflare_oidc_client_id=$(sops -d --extract '["cloudflare"]["oidc_client_id"]' secrets/authentik-cloudflare-oidc.yaml 2>/dev/null)
      export TF_VAR_cloudflare_oidc_client_secret=$(sops -d --extract '["cloudflare"]["oidc_client_secret"]' secrets/authentik-cloudflare-oidc.yaml 2>/dev/null)
      [ -n "$TF_VAR_cloudflare_oidc_client_id" ] && echo "✓ Cloudflare OIDC secrets loaded"
    fi

    # CouchDB OAuth (secrets/authentik-terraform.yaml)
    if [ -f secrets/authentik-terraform.yaml ]; then
      export TF_VAR_couchdb_oauth_client_id=$(sops -d --extract '["couchdb"]["oauth_client_id"]' secrets/authentik-terraform.yaml 2>/dev/null)
      export TF_VAR_couchdb_oauth_client_secret=$(sops -d --extract '["couchdb"]["oauth_client_secret"]' secrets/authentik-terraform.yaml 2>/dev/null)
      [ -n "$TF_VAR_couchdb_oauth_client_id" ] && echo "✓ CouchDB OAuth secrets loaded"
      export TF_VAR_opensearch_oauth_client_id=$(sops -d --extract '["opensearch"]["oauth_client_id"]' secrets/authentik-terraform.yaml 2>/dev/null)
      export TF_VAR_opensearch_oauth_client_secret=$(sops -d --extract '["opensearch"]["oauth_client_secret"]' secrets/authentik-terraform.yaml 2>/dev/null)
      [ -n "$TF_VAR_opensearch_oauth_client_id" ] && echo "✓ OpenSearch OAuth secrets loaded"
    fi
    echo ""

    echo "Terraform commands (cd terraform/):"
    echo "  - terraform init"
    echo "  - terraform plan"
    echo "  - terraform apply"
    echo "  - cf-terraforming (existing resources import tool)"
    echo "======================================="
  '';
}

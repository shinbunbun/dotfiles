/*
  開発シェル設定

  このファイルは開発環境を定義します。
  必要なツールやスクリプトを提供します。

  TF_VAR_* の環境変数は、変数名 → (sops ファイル, 抽出パス) の attrset
  (tfVars) として一元定義し、Nix 側でループ展開して shellHook の
  export 行を生成します。新規アプリの OAuth を追加する際は tfVars に
  1 エントリ追記するだけで済みます。
*/
{ pkgs, inputs, ... }:

let
  inherit (pkgs) lib;

  # sops ファイルのパス (TF_VAR とそれ以外の特殊変数で共有)
  cloudflareFile = "secrets/cloudflare.yaml";
  authentikFile = "secrets/authentik-terraform.yaml";
  grafanaFile = "secrets/grafana.yaml";
  oidcFile = "secrets/authentik-cloudflare-oidc.yaml";

  # TF_VAR_<name> = { file = <sops ファイル>; extract = <sops --extract パス>; }
  # ここに 1 エントリ追記すれば対応する export 行が自動生成される。
  tfVars = {
    # Cloudflare (secrets/cloudflare.yaml)
    TF_VAR_cloudflare_zone_id = {
      file = cloudflareFile;
      extract = ''["cloudflare"]["zone-id"]'';
    };
    TF_VAR_cloudflare_account_id = {
      file = cloudflareFile;
      extract = ''["cloudflare"]["account-id"]'';
    };
    TF_VAR_home_tunnel_id = {
      file = cloudflareFile;
      extract = ''["cloudflare"]["tunnel-id"]'';
    };
    TF_VAR_desktop_tunnel_id = {
      file = cloudflareFile;
      extract = ''["cloudflare"]["desktop-tunnel-id"]'';
    };
    TF_VAR_k3s_tunnel_id = {
      file = cloudflareFile;
      extract = ''["cloudflare"]["k3s-tunnel-id"]'';
    };
    TF_VAR_identity_provider_id = {
      file = cloudflareFile;
      extract = ''["cloudflare"]["identity-provider-id"]'';
    };

    # Authentik / 各アプリ OAuth (secrets/authentik-terraform.yaml)
    TF_VAR_authentik_api_token = {
      file = authentikFile;
      extract = ''["authentik"]["api-token"]'';
    };
    TF_VAR_couchdb_oauth_client_id = {
      file = authentikFile;
      extract = ''["couchdb"]["oauth_client_id"]'';
    };
    TF_VAR_couchdb_oauth_client_secret = {
      file = authentikFile;
      extract = ''["couchdb"]["oauth_client_secret"]'';
    };
    TF_VAR_argocd_oauth_client_id = {
      file = authentikFile;
      extract = ''["argocd"]["oidc_client_id"]'';
    };
    TF_VAR_argocd_oauth_client_secret = {
      file = authentikFile;
      extract = ''["argocd"]["oidc_client_secret"]'';
    };
    TF_VAR_argo_workflows_oauth_client_id = {
      file = authentikFile;
      extract = ''["argo_workflows"]["oauth_client_id"]'';
    };
    TF_VAR_argo_workflows_oauth_client_secret = {
      file = authentikFile;
      extract = ''["argo_workflows"]["oauth_client_secret"]'';
    };
    TF_VAR_nextcloud_oauth_client_id = {
      file = authentikFile;
      extract = ''["nextcloud"]["oauth_client_id"]'';
    };
    TF_VAR_nextcloud_oauth_client_secret = {
      file = authentikFile;
      extract = ''["nextcloud"]["oauth_client_secret"]'';
    };
    TF_VAR_immich_oauth_client_id = {
      file = authentikFile;
      extract = ''["immich"]["oauth_client_id"]'';
    };
    TF_VAR_immich_oauth_client_secret = {
      file = authentikFile;
      extract = ''["immich"]["oauth_client_secret"]'';
    };
    TF_VAR_scanopy_oauth_client_id = {
      file = authentikFile;
      extract = ''["scanopy"]["oauth_client_id"]'';
    };
    TF_VAR_scanopy_oauth_client_secret = {
      file = authentikFile;
      extract = ''["scanopy"]["oauth_client_secret"]'';
    };
    TF_VAR_librechat_oauth_client_id = {
      file = authentikFile;
      extract = ''["librechat"]["oauth_client_id"]'';
    };
    TF_VAR_librechat_oauth_client_secret = {
      file = authentikFile;
      extract = ''["librechat"]["oauth_client_secret"]'';
    };

    # Grafana OAuth (secrets/grafana.yaml)
    TF_VAR_grafana_oauth_client_id = {
      file = grafanaFile;
      extract = ''["grafana"]["oauth_client_id"]'';
    };
    TF_VAR_grafana_oauth_client_secret = {
      file = grafanaFile;
      extract = ''["grafana"]["oauth_client_secret"]'';
    };

    # Cloudflare OIDC (secrets/authentik-cloudflare-oidc.yaml)
    TF_VAR_cloudflare_oidc_client_id = {
      file = oidcFile;
      extract = ''["cloudflare"]["oidc_client_id"]'';
    };
    TF_VAR_cloudflare_oidc_client_secret = {
      file = oidcFile;
      extract = ''["cloudflare"]["oidc_client_secret"]'';
    };
  };

  # tfVars から、必要な sops ファイルが存在するときのみ load_sops_var を
  # 呼ぶ export 行を生成する。ファイル単位でグルーピングして
  # 「ファイルが無い場合はスキップ」のガードを共有する。
  filesUsed = lib.unique (lib.mapAttrsToList (_: v: v.file) tfVars);

  genFileBlock =
    file:
    let
      varsForFile = lib.filterAttrs (_: v: v.file == file) tfVars;
      lines = lib.mapAttrsToList (
        name: v: "load_sops_var ${name} ${lib.escapeShellArg file} ${lib.escapeShellArg v.extract}"
      ) varsForFile;
    in
    ''
      if [ -f ${lib.escapeShellArg file} ]; then
      ${lib.concatStringsSep "\n" lines}
      else
        echo "⚠ Warning: ${file} not found (TF_VAR の一部が未設定です)" >&2
      fi
    '';

  tfVarBlocks = lib.concatStringsSep "\n" (map genFileBlock filesUsed);
in
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

    # SOPS から 1 変数を復号して export するヘルパー。
    # 復号に失敗した場合は 2>/dev/null で握り潰さず、どの変数が
    # 取得できなかったかを stderr に警告 1 行で出す (devShell 自体は止めない)。
    load_sops_var() {
      _name="$1"
      _file="$2"
      _extract="$3"
      # stderr 捕捉先は mktemp で per-call に分離する。固定パス (/tmp/.sops_err)
      # だと並列 devShell や sticky /tmp 上の他ユーザー所有ファイルと衝突しうる。
      _err=$(mktemp)
      _val=$(sops -d --extract "$_extract" "$_file" 2>"$_err") || {
        echo "⚠ Warning: $_name を復号できませんでした ($_file $_extract)" >&2
        sed 's/^/    sops: /' "$_err" >&2
        rm -f "$_err"
        return 0
      }
      rm -f "$_err"
      export "$_name=$_val"
    }

    # Cloudflare API トークン / R2 アクセスキー (TF_VAR 以外の特殊変数)。
    # CLOUDFLARE_API_TOKEN は cf-terraforming と TF_VAR の両方で使うため、
    # sops 呼び出しを増やさないよう TF_VAR_cloudflare_api_token に再利用する。
    if [ -f ${lib.escapeShellArg cloudflareFile} ]; then
      echo "Loading Cloudflare secrets from SOPS..."
      load_sops_var CLOUDFLARE_API_TOKEN ${lib.escapeShellArg cloudflareFile} ${lib.escapeShellArg ''["cloudflare"]["api-token"]''}
      export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
      load_sops_var AWS_ACCESS_KEY_ID ${lib.escapeShellArg cloudflareFile} ${lib.escapeShellArg ''["cloudflare"]["r2-access-key-id"]''}
      load_sops_var AWS_SECRET_ACCESS_KEY ${lib.escapeShellArg cloudflareFile} ${lib.escapeShellArg ''["cloudflare"]["r2-secret-access-key"]''}
      if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
        echo "✓ Cloudflare API token / R2 keys loaded from SOPS"
      fi
    else
      echo "⚠ Warning: ${cloudflareFile} not found" >&2
    fi

    # tfVars から自動生成した TF_VAR_* の export 行 (ファイル単位ガード付き)。
    ${tfVarBlocks}

    echo ""
    echo "Terraform commands (cd terraform/):"
    echo "  - terraform init"
    echo "  - terraform plan"
    echo "  - terraform apply"
    echo "  - cf-terraforming (existing resources import tool)"
    echo "======================================="
  '';
}

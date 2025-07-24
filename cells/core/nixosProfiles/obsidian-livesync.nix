# cells/core/nixosProfiles/obsidian-livesync.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # Obsidian LiveSync用のSOPS secrets設定
  sops = {
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets."couchdb_admin_password" = {
      key = "couchdb/admin_password";
      sopsFile = "${inputs.self}/secrets/couchdb.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."couchdb_database_name" = {
      key = "couchdb/database_name";
      sopsFile = "${inputs.self}/secrets/couchdb.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."cloudflare_tunnel_token" = {
      key = "cloudflare/tunnel_token";
      sopsFile = "${inputs.self}/secrets/couchdb.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."cloudflare_account_tag" = {
      key = "cloudflare/account_tag";
      sopsFile = "${inputs.self}/secrets/couchdb.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."cloudflare_tunnel_secret" = {
      key = "cloudflare/tunnel_secret";
      sopsFile = "${inputs.self}/secrets/couchdb.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    secrets."cloudflare_tunnel_id" = {
      key = "cloudflare/tunnel_id";
      sopsFile = "${inputs.self}/secrets/couchdb.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # CouchDB environment file template
    templates."couchdb/env" = {
      content = ''
        COUCHDB_USER=admin
        COUCHDB_PASSWORD=${config.sops.placeholder."couchdb_admin_password"}
      '';
      path = "/run/secrets/rendered/couchdb/env";
      owner = "root";
      group = "root";
      mode = "0640";
    };

    # Cloudflare credentials file template
    templates."cloudflare/credentials.json" = {
      content = ''
        {
          "AccountTag": "${config.sops.placeholder."cloudflare_account_tag"}",
          "TunnelSecret": "${config.sops.placeholder."cloudflare_tunnel_secret"}",
          "TunnelID": "${config.sops.placeholder."cloudflare_tunnel_id"}"
        }
      '';
      path = "/run/secrets/rendered/cloudflare/credentials.json";
      owner = "root";
      group = "root";
      mode = "0640";
    };
  };

  # CouchDBデータディレクトリの作成
  systemd.tmpfiles.rules = [
    "d /var/lib/couchdb 0755 root docker -"
    "d /var/lib/couchdb/data 0755 999 999 -"
  ];

  # CouchDB OCI Container
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      couchdb-obsidian = {
        image = "couchdb:3.3.3";
        autoStart = true;
        ports = [ "127.0.0.1:5984:5984" ];
        volumes = [
          "/var/lib/couchdb/data:/opt/couchdb/data"
        ];
        environmentFiles = [
          config.sops.templates."couchdb/env".path
        ];
        extraOptions = [
          "--health-cmd=curl -f http://localhost:5984/ || exit 1"
          "--health-interval=30s"
          "--health-timeout=10s"
          "--health-retries=3"
        ];
      };
    };
  };

  # CouchDB データベース初期化サービス
  systemd.services.couchdb-init = {
    description = "Initialize CouchDB databases";
    after = [ "docker-couchdb-obsidian.service" ];
    wants = [ "docker-couchdb-obsidian.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # systemdのLoadCredentialを使用してシークレットを安全に渡す
      LoadCredential = [
        "couchdb_admin_password:${config.sops.secrets."couchdb_admin_password".path}"
        "couchdb_database_name:${config.sops.secrets."couchdb_database_name".path}"
      ];
      ExecStart = pkgs.writeScript "couchdb-init" ''
        #!${pkgs.bash}/bin/bash
        set -e

        echo "Waiting for CouchDB to be ready..."
        for i in {1..30}; do
          if ${pkgs.curl}/bin/curl -f http://localhost:5984/ >/dev/null 2>&1; then
            echo "CouchDB is ready!"
            break
          fi
          echo "Attempt $i/30: CouchDB not ready yet, waiting..."
          sleep 2
        done

        # systemdのCREDENTIALS_DIRECTORYからパスワードを読み込む
        PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/couchdb_admin_password")

        # 認証情報用の一時ファイルを作成（安全なディレクトリに）
        NETRC_FILE=$(mktemp)
        chmod 600 "$NETRC_FILE"
        echo "machine localhost login admin password $PASSWORD" > "$NETRC_FILE"
        
        # netrc-fileオプションを使用して安全に認証
        echo "Creating obsidian-livesync database..."
        ${pkgs.curl}/bin/curl -f --netrc-file "$NETRC_FILE" \
          -X PUT http://localhost:5984/obsidian-livesync 2>/dev/null || {
          echo "Database obsidian-livesync already exists or creation failed"
        }

        # Create database for the configured database name
        DATABASE_NAME=$(cat "$CREDENTIALS_DIRECTORY/couchdb_database_name")
        echo "Creating $DATABASE_NAME database..."
        ${pkgs.curl}/bin/curl -f --netrc-file "$NETRC_FILE" \
          -X PUT http://localhost:5984/$DATABASE_NAME 2>/dev/null || {
          echo "Database $DATABASE_NAME already exists or creation failed"
        }

        # Configure CORS settings via CouchDB API
        echo "Configuring CORS settings..."
        ${pkgs.curl}/bin/curl -f --netrc-file "$NETRC_FILE" \
          -X PUT http://localhost:5984/_node/nonode@nohost/_config/httpd/enable_cors \
          -H "Content-Type: application/json" \
          -d '"true"' 2>/dev/null || echo "CORS enable setting failed"

        ${pkgs.curl}/bin/curl -f --netrc-file "$NETRC_FILE" \
          -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/origins \
          -H "Content-Type: application/json" \
          -d '"app://obsidian.md,capacitor://localhost,http://localhost,https://private-obsidian.${
            if config.networking ? domain && config.networking.domain != null then
              config.networking.domain
            else
              "shinbunbun.com"
          }"' 2>/dev/null || echo "CORS origins setting failed"

        ${pkgs.curl}/bin/curl -f --netrc-file "$NETRC_FILE" \
          -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/credentials \
          -H "Content-Type: application/json" \
          -d '"true"' 2>/dev/null || echo "CORS credentials setting failed"

        ${pkgs.curl}/bin/curl -f --netrc-file "$NETRC_FILE" \
          -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/methods \
          -H "Content-Type: application/json" \
          -d '"GET,PUT,POST,HEAD,DELETE,OPTIONS"' 2>/dev/null || echo "CORS methods setting failed"

        ${pkgs.curl}/bin/curl -f --netrc-file "$NETRC_FILE" \
          -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/headers \
          -H "Content-Type: application/json" \
          -d '"accept,authorization,content-type,origin,referer,x-couch-request-id,x-requested-with"' 2>/dev/null || echo "CORS headers setting failed"

        # 一時ファイルを削除
        rm -f "$NETRC_FILE"

        echo "CouchDB initialization completed successfully!"
      '';
    };
  };

  # Cloudflare Tunnel for Obsidian LiveSync
  services.cloudflared = {
    enable = true;
    tunnels = {
      "obsidian-livesync" = {
        default = "http_status:404";
        credentialsFile = config.sops.templates."cloudflare/credentials.json".path;
        ingress = {
          # CouchDB for Obsidian LiveSync
          "private-obsidian.${
            if config.networking ? domain && config.networking.domain != null then
              config.networking.domain
            else
              "shinbunbun.com"
          }" =
            {
              service = "http://localhost:5984";
              originRequest = {
                noTLSVerify = true;
              };
            };
        };
      };
    };
  };
}

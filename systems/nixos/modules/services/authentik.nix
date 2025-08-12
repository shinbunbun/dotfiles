/*
  Authentik IdP (Identity Provider) 設定モジュール

  このモジュールはAuthentikセルフホストIdPを提供します：
  - OAuth2/OIDC認証プロバイダー
  - SAML2プロバイダー
  - WebAuthn/Passkey対応
  - 統一認証基盤として他サービスと連携

  Authentikを使用することで、CouchDBを含む複数のサービスで
  シングルサインオン（SSO）を実現できます。
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # ドメイン設定
  domain =
    if config.networking ? domain && config.networking.domain != null then
      config.networking.domain
    else
      "shinbunbun.com";
in
{
  # SOPSシークレット設定
  sops.secrets = {
    "authentik_secret_key" = {
      sopsFile = "${inputs.self}/secrets/authentik.yaml";
    };
    "authentik_postgresql_password" = {
      sopsFile = "${inputs.self}/secrets/authentik.yaml";
    };
    "authentik_redis_password" = {
      sopsFile = "${inputs.self}/secrets/authentik.yaml";
    };
    "authentik_email_host" = {
      sopsFile = "${inputs.self}/secrets/authentik.yaml";
    };
    "authentik_email_username" = {
      sopsFile = "${inputs.self}/secrets/authentik.yaml";
    };
    "authentik_email_password" = {
      sopsFile = "${inputs.self}/secrets/authentik.yaml";
    };

    # Cloudflare Tunnel用シークレット
    "authentik_cloudflare_account_tag" = {
      key = "cloudflare_account_tag";
      sopsFile = "${inputs.self}/secrets/authentik-tunnel.yaml";
    };
    "authentik_cloudflare_tunnel_secret" = {
      key = "cloudflare_tunnel_secret";
      sopsFile = "${inputs.self}/secrets/authentik-tunnel.yaml";
    };
    "authentik_cloudflare_tunnel_id" = {
      key = "cloudflare_tunnel_id";
      sopsFile = "${inputs.self}/secrets/authentik-tunnel.yaml";
    };
  };

  # SOPSテンプレート設定
  sops.templates = {
    # Authentik環境設定ファイル
    "authentik/env" = {
      content = ''
        # PostgreSQL設定
        POSTGRES_PASSWORD=${config.sops.placeholder."authentik_postgresql_password"}
        AUTHENTIK_POSTGRESQL__PASSWORD=${config.sops.placeholder."authentik_postgresql_password"}

        # Redis設定
        AUTHENTIK_REDIS__PASSWORD=${config.sops.placeholder."authentik_redis_password"}

        # セキュリティ設定
        AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik_secret_key"}

        # Email設定（オプション）
        AUTHENTIK_EMAIL__HOST=${config.sops.placeholder."authentik_email_host"}
        AUTHENTIK_EMAIL__USERNAME=${config.sops.placeholder."authentik_email_username"}
        AUTHENTIK_EMAIL__PASSWORD=${config.sops.placeholder."authentik_email_password"}
        AUTHENTIK_EMAIL__PORT=587
        AUTHENTIK_EMAIL__USE_TLS=true
        AUTHENTIK_EMAIL__FROM=noreply@${domain}

        # その他の設定
        AUTHENTIK_ERROR_REPORTING__ENABLED=false
        AUTHENTIK_LOG_LEVEL=info
      '';
      path = "/run/secrets/rendered/authentik/env";
      owner = "root";
      group = "root";
      mode = "0640";
    };

    # Cloudflare認証情報ファイル
    "cloudflare/authentik-credentials.json" = {
      content = builtins.toJSON {
        AccountTag = config.sops.placeholder."authentik_cloudflare_account_tag";
        TunnelSecret = config.sops.placeholder."authentik_cloudflare_tunnel_secret";
        TunnelID = config.sops.placeholder."authentik_cloudflare_tunnel_id";
      };
      path = "/run/secrets/rendered/cloudflare/authentik-credentials.json";
      owner = "root";
      group = "root";
      mode = "0640";
    };
  };

  # データディレクトリの作成
  systemd.tmpfiles.rules = [
    "d /var/lib/authentik 0755 root docker -"
    "d /var/lib/authentik/postgresql 0755 999 999 -"
    "d /var/lib/authentik/redis 0755 999 999 -"
    "d /var/lib/authentik/media 0755 1000 1000 -"
    "d /var/lib/authentik/templates 0755 1000 1000 -"
    "d /var/lib/authentik/geoip 0755 1000 1000 -"
  ];

  # Docker Composeスタイルの設定
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      # PostgreSQLデータベース
      authentik-postgresql = {
        image = "postgres:16-alpine";
        autoStart = true;
        volumes = [
          "/var/lib/authentik/postgresql:/var/lib/postgresql/data"
        ];
        environment = {
          POSTGRES_DB = "authentik";
          POSTGRES_USER = "authentik";
          # PG_PASSはenvironmentFilesから読み込まれるので、ここでは設定しない
        };
        environmentFiles = [
          config.sops.templates."authentik/env".path
        ];
        extraOptions = [
          "--network=authentik"
          "--health-cmd=pg_isready -U authentik"
          "--health-interval=30s"
          "--health-timeout=10s"
          "--health-retries=3"
        ];
      };

      # Redisキャッシュ
      authentik-redis = {
        image = "redis:7-alpine";
        autoStart = true;
        volumes = [
          "/var/lib/authentik/redis:/data"
          "/run/secrets/rendered/authentik/env:/tmp/env:ro"
        ];
        cmd = [
          "sh"
          "-c"
          ''
            . /tmp/env
            exec redis-server --save 60 1 --loglevel warning --requirepass "$AUTHENTIK_REDIS__PASSWORD"
          ''
        ];
        extraOptions = [
          "--network=authentik"
          "--health-cmd=redis-cli ping"
          "--health-interval=30s"
          "--health-timeout=10s"
          "--health-retries=3"
        ];
      };

      # Authentikサーバー
      authentik-server = {
        image = "ghcr.io/goauthentik/server:2024.10";
        autoStart = true;
        dependsOn = [
          "authentik-postgresql"
          "authentik-redis"
        ];
        ports = [ "127.0.0.1:9000:9000" ];
        volumes = [
          "/var/lib/authentik/media:/media"
          "/var/lib/authentik/templates:/templates"
          "/var/lib/authentik/geoip:/geoip"
        ];
        environment = {
          AUTHENTIK_REDIS__HOST = "authentik-redis";
          AUTHENTIK_POSTGRESQL__HOST = "authentik-postgresql";
          AUTHENTIK_POSTGRESQL__USER = "authentik";
          AUTHENTIK_POSTGRESQL__NAME = "authentik";
        };
        environmentFiles = [
          config.sops.templates."authentik/env".path
        ];
        cmd = [ "server" ];
        extraOptions = [
          "--network=authentik"
        ];
      };

      # Authentikワーカー
      authentik-worker = {
        image = "ghcr.io/goauthentik/server:2024.10";
        autoStart = true;
        dependsOn = [
          "authentik-postgresql"
          "authentik-redis"
        ];
        volumes = [
          "/var/lib/authentik/media:/media"
          "/var/lib/authentik/templates:/templates"
          "/var/lib/authentik/geoip:/geoip"
        ];
        environment = {
          AUTHENTIK_REDIS__HOST = "authentik-redis";
          AUTHENTIK_POSTGRESQL__HOST = "authentik-postgresql";
          AUTHENTIK_POSTGRESQL__USER = "authentik";
          AUTHENTIK_POSTGRESQL__NAME = "authentik";
        };
        environmentFiles = [
          config.sops.templates."authentik/env".path
        ];
        cmd = [ "worker" ];
        extraOptions = [
          "--network=authentik"
        ];
      };
    };
  };

  # Dockerネットワークの作成
  systemd.services.docker-network-authentik = {
    description = "Create Docker network for Authentik";
    after = [ "docker.service" ];
    before = [
      "docker-authentik-postgresql.service"
      "docker-authentik-redis.service"
      "docker-authentik-server.service"
      "docker-authentik-worker.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker network create authentik || true'";
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker network rm authentik || true'";
    };
    wantedBy = [ "multi-user.target" ];
  };

  # ファイアウォール設定（内部アクセスのみ）
  # Authentikへの外部からの直接アクセスは許可しない（Cloudflare Tunnel経由のみ）
}

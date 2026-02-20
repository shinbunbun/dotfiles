/*
  Attic Binary Cache Server設定モジュール

  このモジュールはNix Binary Cacheサーバーを提供します：
  - PostgreSQL + ローカルストレージによるバックエンド
  - peer認証によるセキュアなDB接続
  - チャンクベースの重複排除
  - 自動ガベージコレクション（30日保持）
  - Cloudflare Tunnel経由での公開
  - JWT認証によるアクセス制御

  使用方法:
  - CIからプッシュ: attic push main <path>
  - 各マシンで利用: nix.settings.substituters に追加
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;
  port = cfg.attic.port;
  domain = cfg.attic.domain;
  storagePath = cfg.attic.storagePath;
  dbName = cfg.attic.database.name;
  dbUser = cfg.attic.database.user;
in
{
  # SOPS シークレット設定
  sops.secrets = {
    "attic_jwt_secret_base64" = {
      sopsFile = "${inputs.self}/secrets/attic.yaml";
      # atticdユーザーはservices.atticdで動的に作成されるため、rootが所有
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  # SOPS テンプレート設定
  sops.templates."attic/env" = {
    content = ''
      ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder."attic_jwt_secret_base64"}
    '';
    path = "/run/secrets/rendered/attic/env";
    # テンプレートもrootが所有、atticdサービスが読み取る
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # PostgreSQL設定（peer認証）
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ dbName ];
    ensureUsers = [
      {
        name = dbUser;
        ensureDBOwnership = true;
      }
    ];

    # peer認証でatticdユーザーからatticDBユーザーへのマッピング
    identMap = ''
      attic-users atticd ${dbUser}
    '';

    authentication = lib.mkAfter ''
      local ${dbName} ${dbUser} peer map=attic-users
    '';
  };

  # Atticd サービス設定
  services.atticd = {
    enable = true;

    environmentFile = config.sops.templates."attic/env".path;

    settings = {
      listen = "[::]:${toString port}";
      allowed-hosts = [
        domain
        "192.168.1.3:8080"
      ];
      database = {
        # peer認証 + Unix socket + 明示的なユーザー名指定
        url = "postgresql:///${dbName}?host=/run/postgresql&user=${dbUser}";
      };

      storage = {
        type = "local";
        path = storagePath;
      };

      chunking = {
        nar-size-threshold = cfg.attic.chunking.narSizeThreshold;
        min-size = cfg.attic.chunking.minSize;
        avg-size = cfg.attic.chunking.avgSize;
        max-size = cfg.attic.chunking.maxSize;
      };

      compression = {
        type = cfg.attic.compression.type;
        level = cfg.attic.compression.level;
      };

      garbage-collection = {
        interval = cfg.attic.garbageCollection.interval;
        default-retention-period = cfg.attic.garbageCollection.retentionPeriod;
      };
    };
  };

  # ストレージディレクトリの作成
  # atticdはDynamicUserのため、rebuild時にユーザーが存在しない場合がある
  # root所有で作成し、サービス側のReadWritePathsで書き込み権限を確保
  # /var/lib/atticdはDynamicUserが自動管理（symlink → private/atticd）するため不要
  systemd.tmpfiles.rules = [
    "d ${storagePath} 0755 root root -"
  ];

  # systemd設定の調整（Atticモジュールのデフォルトを拡張）
  systemd.services.atticd = {
    after = [
      "postgresql.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [ "postgresql.service" ];
    serviceConfig = {
      ReadWritePaths = [ storagePath ];
    };
  };

  # ファイアウォール設定
  networking.firewall.allowedTCPPorts = [ port ];
}

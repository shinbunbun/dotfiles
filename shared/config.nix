# cells/core/config.nix
/*
  中央設定モジュール

  このモジュールはシステム全体の設定値を一元管理します：
  - システム設定: stateVersion、タイムゾーン
  - Git設定: ユーザー情報、GPG署名
  - ネットワーク設定: ホスト名、インターフェース
  - SSH設定: ポート、鍵パス
  - NFS設定: エクスポート、許可ホスト
  - WireGuard設定: VPN接続情報
  - RouterOSバックアップ設定
  - 監視システム設定: Prometheus、Grafana、Alertmanager
  - Fail2ban設定: 除外ネットワーク
  - SOPS設定: 秘密鍵パス
  - CouchDB設定: コンテナ名、JWT設定
  - Authentik設定: ドメイン

  型チェックとアサーションを含み、設定エラーを
  早期に発見できるようにしています。このファイルを
  編集することで、システム全体の設定を一括で変更できます。
*/
let
  # 型チェック用のヘルパー関数
  assertType =
    name: value: predicate: message:
    if predicate value then
      value
    else
      throw "Config validation error for '${name}': ${message}. Got: ${builtins.toJSON value}";

  # IPアドレスの検証
  isValidIP = ip: builtins.match ''^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'' ip != null;

  # ポート番号の検証
  isValidPort = port: builtins.isInt port && port >= 1 && port <= 65535;

  # CIDR表記の検証
  isValidCIDR =
    cidr: builtins.match ''^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$'' cidr != null;

  # パスの検証
  isValidPath = path: builtins.isString path && builtins.substring 0 1 path == "/";

  # メールアドレスの簡易検証
  isValidEmail = email: builtins.match "^[^@]+@[^@]+" email != null;

  # 設定値の定義
  config = {
    # ユーザー設定
    users = {
      nixos = {
        username = assertType "users.nixos.username" "bunbun" builtins.isString "Must be a string";
        homeDirectory =
          assertType "users.nixos.homeDirectory" "/home/bunbun" isValidPath
            "Must be an absolute path";
      };
      darwin = {
        username = assertType "users.darwin.username" "shinbunbun" builtins.isString "Must be a string";
        homeDirectory =
          assertType "users.darwin.homeDirectory" "/Users/shinbunbun" isValidPath
            "Must be an absolute path";
      };
    };

    # Git設定
    git = {
      userName = assertType "git.userName" "shinbunbun" builtins.isString "Must be a string";
      userEmail = assertType "git.userEmail" "34409044+shinbunbun@users.noreply.github.com" (
        email: builtins.isString email && isValidEmail email
      ) "Must be a valid email address";
      coreEditor = assertType "git.coreEditor" "code --wait" builtins.isString "Must be a string";
    };

    # システムバージョン設定
    system = {
      nixosStateVersion =
        assertType "system.nixosStateVersion" "21.11" builtins.isString
          "Must be a string";
      homeStateVersion =
        assertType "system.homeStateVersion" "24.11" builtins.isString
          "Must be a string";
      timeZone = assertType "system.timeZone" "Asia/Tokyo" builtins.isString "Must be a string";
    };

    # ネットワーク設定
    networking = {
      # ホスト情報
      hosts = {
        nixos = {
          hostname =
            assertType "networking.hosts.nixos.hostname" "nixos" builtins.isString
              "Must be a string";
          domain =
            assertType "networking.hosts.nixos.domain" "shinbunbun.com" builtins.isString
              "Must be a string";
        };
        nixosDesktop = {
          ip =
            assertType "networking.hosts.nixosDesktop.ip" "192.168.1.4" isValidIP
              "Must be a valid IP address";
          hostname =
            assertType "networking.hosts.nixosDesktop.hostname" "nixos-desktop" builtins.isString
              "Must be a string";
        };
      };

      # インターフェース設定
      interfaces = {
        primary = assertType "networking.interfaces.primary" "eno1" builtins.isString "Must be a string";
        wireless =
          assertType "networking.interfaces.wireless" "wlp1s0" builtins.isString
            "Must be a string";
      };

      # 許可されたネットワーク
      allowedNetworks = [
        "192.168.1.0/24" # ローカルネットワーク1
        "192.168.11.0/24" # ローカルネットワーク2
        "10.100.0.0/24" # WireGuardネットワーク
      ];

      # ファイアウォール設定
      firewall = {
        generalPort =
          assertType "networking.firewall.generalPort" 8888 isValidPort
            "Must be a valid port number (1-65535)";
        nfsPort =
          assertType "networking.firewall.nfsPort" 2049 isValidPort
            "Must be a valid port number (1-65535)";
      };
    };

    # SSH設定
    ssh = {
      port = assertType "ssh.port" 31415 isValidPort "Must be a valid port number (1-65535)";
      authorizedKeysPath =
        assertType "ssh.authorizedKeysPath" "/etc/ssh/authorized_keys.d/%u" builtins.isString
          "Must be a string";
    };

    # Fail2ban設定
    fail2ban = {
      ignoreNetworks =
        map (cidr: assertType "fail2ban.ignoreNetworks" cidr isValidCIDR "Must be a valid CIDR notation")
          [
            "192.168.11.0/24"
            "163.143.0.0/16"
          ];
    };

    # SOPS設定
    sops = {
      keyFile =
        assertType "sops.keyFile" "/var/lib/sops-nix/key.txt" isValidPath
          "Must be an absolute path";
    };

    # k3s設定
    k3s = {
      # デスクトップ用k3s設定
      desktop = {
        enable = assertType "k3s.desktop.enable" true builtins.isBool "Must be a boolean";
        role = assertType "k3s.desktop.role" "server" (
          role:
          builtins.elem role [
            "server"
            "agent"
          ]
        ) "Must be either 'server' or 'agent'";

        # サーバー設定
        clusterInit = assertType "k3s.desktop.clusterInit" true builtins.isBool "Must be a boolean";

        # 追加フラグ
        extraFlags = [
          "--flannel-backend=vxlan"
          "--write-kubeconfig-mode=0644"
        ];
      };

      # 将来のhomeMachine用設定（現時点では無効）
      homeMachine = {
        enable = assertType "k3s.homeMachine.enable" false builtins.isBool "Must be a boolean";
        role = assertType "k3s.homeMachine.role" "agent" (
          role:
          builtins.elem role [
            "server"
            "agent"
          ]
        ) "Must be either 'server' or 'agent'";
      };
    };

    # NFS設定
    nfs = {
      exportPath = assertType "nfs.exportPath" "/export/k8s" isValidPath "Must be an absolute path";
      clients = [
        { ip = assertType "nfs.clients[0].ip" "192.168.1.3" isValidIP "Must be a valid IP address"; }
        { ip = assertType "nfs.clients[1].ip" "192.168.1.4" isValidIP "Must be a valid IP address"; }
      ];
      options =
        assertType "nfs.options" "rw,nohide,insecure,no_subtree_check,no_root_squash" builtins.isString
          "Must be a string";
    };

    # WireGuard設定
    wireguard = {
      # 共通設定
      network = {
        subnet =
          assertType "wireguard.network.subnet" "10.100.0.0/24" isValidCIDR
            "Must be a valid CIDR notation";
        serverIp =
          assertType "wireguard.network.serverIp" "10.100.0.1" isValidIP
            "Must be a valid IP address";
      };

      # NixOS用設定
      nixos = {
        interfaceName =
          assertType "wireguard.nixos.interfaceName" "wg0" builtins.isString
            "Must be a string";
        clientIp =
          assertType "wireguard.nixos.clientIp" "10.100.0.4" isValidIP
            "Must be a valid IP address";
        serverEndpoint =
          assertType "wireguard.nixos.serverEndpoint" "192.168.1.1:13231" builtins.isString
            "Must be a string";
        privateKeyPath =
          assertType "wireguard.nixos.privateKeyPath" "wireguard/home/nixosClientPrivKey" builtins.isString
            "Must be a string";
        publicKeyPath =
          assertType "wireguard.nixos.publicKeyPath" "wireguard/home/publicKey" builtins.isString
            "Must be a string";
      };

      # Darwin(macOS)用設定
      darwin = {
        interfaceName =
          assertType "wireguard.darwin.interfaceName" "wg-home" builtins.isString
            "Must be a string";
        clientIp =
          assertType "wireguard.darwin.clientIp" "10.100.0.2" isValidIP
            "Must be a valid IP address";
        privateKeyPath =
          assertType "wireguard.darwin.privateKeyPath" "wireguard/home/macClientPrivKey" builtins.isString
            "Must be a string";
        publicKeyPath =
          assertType "wireguard.darwin.publicKeyPath" "wireguard/home/publicKey" builtins.isString
            "Must be a string";
        endpointPath =
          assertType "wireguard.darwin.endpointPath" "wireguard/home/endpoint" builtins.isString
            "Must be a string";
        allowedNetworks =
          map
            (
              cidr: assertType "wireguard.darwin.allowedNetworks" cidr isValidCIDR "Must be a valid CIDR notation"
            )
            [
              "192.168.1.0/24"
              "10.100.0.0/24"
            ];
      };

      # 共通のkeepalive設定
      persistentKeepalive = assertType "wireguard.persistentKeepalive" 25 (
        n: builtins.isInt n && n > 0
      ) "Must be a positive integer";
    };

    # RouterOSバックアップ設定
    routerosBackup = {
      routerIP =
        assertType "routerosBackup.routerIP" "192.168.1.1" isValidIP
          "Must be a valid IP address";
      routerUser = assertType "routerosBackup.routerUser" "admin" builtins.isString "Must be a string";
      sshKeyPath =
        assertType "routerosBackup.sshKeyPath" "/home/bunbun/.ssh/id_ed25519" isValidPath
          "Must be an absolute path";
      backupDir =
        assertType "routerosBackup.backupDir" "/var/lib/routeros-backup" isValidPath
          "Must be an absolute path";
      git = {
        userName =
          assertType "routerosBackup.git.userName" "RouterOS Backup Service" builtins.isString
            "Must be a string";
        userEmail = assertType "routerosBackup.git.userEmail" "routeros-backup@localhost" (
          email: builtins.isString email && isValidEmail email
        ) "Must be a valid email address";
      };
      # リトライ設定
      maxRetries = assertType "routerosBackup.maxRetries" 3 (
        n: builtins.isInt n && n > 0
      ) "Must be a positive integer";
      retryDelay = assertType "routerosBackup.retryDelay" 30 (
        n: builtins.isInt n && n > 0
      ) "Must be a positive integer";
    };

    # 監視システム設定
    monitoring = {
      # Prometheus設定
      prometheus = {
        port =
          assertType "monitoring.prometheus.port" 9090 isValidPort
            "Must be a valid port number (1-65535)";
        retentionDays = assertType "monitoring.prometheus.retentionDays" 30 (
          n: builtins.isInt n && n > 0
        ) "Must be a positive integer";
        scrapeInterval =
          assertType "monitoring.prometheus.scrapeInterval" "15s" builtins.isString
            "Must be a string";
        evaluationInterval =
          assertType "monitoring.prometheus.evaluationInterval" "15s" builtins.isString
            "Must be a string";
      };

      # Node Exporter設定
      nodeExporter = {
        port =
          assertType "monitoring.nodeExporter.port" 9100 isValidPort
            "Must be a valid port number (1-65535)";
      };

      # Grafana設定
      grafana = {
        port =
          assertType "monitoring.grafana.port" 3000 isValidPort
            "Must be a valid port number (1-65535)";
        domain =
          assertType "monitoring.grafana.domain" "grafana.shinbunbun.com" builtins.isString
            "Must be a string";
      };

      # Alertmanager設定
      alertmanager = {
        port =
          assertType "monitoring.alertmanager.port" 9093 isValidPort
            "Must be a valid port number (1-65535)";
      };

      # SNMP Exporter設定
      snmpExporter = {
        port =
          assertType "monitoring.snmpExporter.port" 9116 isValidPort
            "Must be a valid port number (1-65535)";
        communityString =
          assertType "monitoring.snmpExporter.communityString" "prometheus" builtins.isString
            "Must be a string";
      };

      # Loki設定
      loki = {
        port = assertType "monitoring.loki.port" 3100 isValidPort "Must be a valid port number (1-65535)";
        retentionDays = assertType "monitoring.loki.retentionDays" 30 (
          n: builtins.isInt n && n > 0
        ) "Must be a positive integer (days to retain logs)";
        ingestionRateLimit = assertType "monitoring.loki.ingestionRateLimit" 52428800 (
          n: builtins.isInt n && n > 0
        ) "Must be a positive integer (bytes per second)"; # 50MB/s
        ingestionBurstSize = assertType "monitoring.loki.ingestionBurstSize" 104857600 (
          n: builtins.isInt n && n > 0
        ) "Must be a positive integer (bytes)"; # 100MB
        chunkTargetSize = assertType "monitoring.loki.chunkTargetSize" 1572864 (
          n: builtins.isInt n && n > 0
        ) "Must be a positive integer (bytes)";
        dataDir =
          assertType "monitoring.loki.dataDir" "/var/lib/loki" isValidPath
            "Must be an absolute path";
      };

    };

    # CouchDB設定
    couchdb = {
      containerName =
        assertType "couchdb.containerName" "couchdb-obsidian" builtins.isString
          "Must be a string";
      port = assertType "couchdb.port" 5984 isValidPort "Must be a valid port number (1-65535)";
      configPath =
        assertType "couchdb.configPath" "/opt/couchdb/etc/local.d/10-jwt.ini" isValidPath
          "Must be an absolute path";
      jwt = {
        rolesClaimPath =
          assertType "couchdb.jwt.rolesClaimPath" "groups" builtins.isString
            "Must be a string";
        allowedAlgorithms =
          assertType "couchdb.jwt.allowedAlgorithms" "ES256" builtins.isString
            "Must be a string";
      };
    };

    # Authentik設定
    authentik = {
      domain = assertType "authentik.domain" "auth.shinbunbun.com" builtins.isString "Must be a string";
      baseUrl =
        assertType "authentik.baseUrl" "https://auth.shinbunbun.com" builtins.isString
          "Must be a string";
    };

    # Cloudflare Tunnel設定
    cloudflare = {
      # nixos-desktop用トンネル設定
      desktop = {
        cockpit = {
          domain =
            assertType "cloudflare.desktop.cockpit.domain" "desktop-cockpit.shinbunbun.com" builtins.isString
              "Must be a string";
        };
        ttyd = {
          domain =
            assertType "cloudflare.desktop.ttyd.domain" "desktop-terminal.shinbunbun.com" builtins.isString
              "Must be a string";
        };
        calendarBot = {
          domain =
            assertType "cloudflare.desktop.calendarBot.domain" "calendar-bot.shinbunbun.com" builtins.isString
              "Must be a string";
        };
      };
    };

    # 管理インターフェース設定
    management = {
      # Cockpit設定
      cockpit = {
        enable = assertType "management.cockpit.enable" true builtins.isBool "Must be a boolean";
        port =
          assertType "management.cockpit.port" 9091 isValidPort
            "Must be a valid port number (1-65535)";
        domain =
          assertType "management.cockpit.domain" "cockpit.shinbunbun.com" builtins.isString
            "Must be a string";
      };

      # ttyd設定
      ttyd = {
        enable = assertType "management.ttyd.enable" true builtins.isBool "Must be a boolean";
        port = assertType "management.ttyd.port" 7681 isValidPort "Must be a valid port number (1-65535)";
        domain =
          assertType "management.ttyd.domain" "terminal.shinbunbun.com" builtins.isString
            "Must be a string";
        passwordFile =
          assertType "management.ttyd.passwordFile" "/var/lib/ttyd/password" isValidPath
            "Must be an absolute path";
      };

      # アクセス制限設定
      access = {
        allowedNetworks =
          map
            (
              cidr:
              assertType "management.access.allowedNetworks" cidr isValidCIDR "Must be a valid CIDR notation"
            )
            [
              "192.168.1.0/24"
              "192.168.11.0/24"
              "10.100.0.0/24" # WireGuard
            ];
        wireguardInterface =
          assertType "management.access.wireguardInterface" "wg0" builtins.isString
            "Must be a string";
      };
    };

    # OpenSearch設定
    opensearch = {
      # サーバー設定
      port = assertType "opensearch.port" 9200 isValidPort "Must be a valid port number (1-65535)";
      transportPort =
        assertType "opensearch.transportPort" 9300 isValidPort
          "Must be a valid port number (1-65535)";
      dataDir =
        assertType "opensearch.dataDir" "/var/lib/opensearch" isValidPath
          "Must be an absolute path";

      # メモリ設定（現在のログ量に最適化: 8GB）
      heapSize = assertType "opensearch.heapSize" "8g" builtins.isString "Must be a string";
      maxMemory = assertType "opensearch.maxMemory" 10737418240 (
        n: builtins.isInt n && n > 0
      ) "Must be a positive integer (bytes)"; # 8GB + 2GB（システム用）= 10GB

      # クラスター設定
      clusterName =
        assertType "opensearch.clusterName" "shinbunbun-logs" builtins.isString
          "Must be a string";
      nodeName = assertType "opensearch.nodeName" "nixos-desktop" builtins.isString "Must be a string";

      # インデックス設定
      numberOfShards = assertType "opensearch.numberOfShards" 1 (
        n: builtins.isInt n && n > 0
      ) "Must be a positive integer"; # 単一ノードのため
      numberOfReplicas = assertType "opensearch.numberOfReplicas" 0 (
        n: builtins.isInt n && n >= 0
      ) "Must be a non-negative integer"; # レプリカ不要

      # セキュリティ設定
      enableSecurity = assertType "opensearch.enableSecurity" true builtins.isBool "Must be a boolean";
      allowedNetworks =
        map (cidr: assertType "opensearch.allowedNetworks" cidr isValidCIDR "Must be a valid CIDR notation")
          [
            "192.168.1.0/24"
            "192.168.11.0/24"
            "10.100.0.0/24" # WireGuard
          ];
    };

    # OpenSearch Dashboards設定
    opensearchDashboards = {
      port =
        assertType "opensearchDashboards.port" 5601 isValidPort
          "Must be a valid port number (1-65535)";
      domain =
        assertType "opensearchDashboards.domain" "opensearch.shinbunbun.com" builtins.isString
          "Must be a string";
      opensearchUrl =
        assertType "opensearchDashboards.opensearchUrl" "http://192.168.1.4:9200" builtins.isString
          "Must be a string";
    };

    # Fluent Bit設定
    fluentBit = {
      port = assertType "fluentBit.port" 2020 isValidPort "Must be a valid port number (1-65535)";
      syslogPort =
        assertType "fluentBit.syslogPort" 514 isValidPort
          "Must be a valid port number (1-65535)";
      opensearchHost =
        assertType "fluentBit.opensearchHost" "192.168.1.4" isValidIP
          "Must be a valid IP address";
      opensearchPort =
        assertType "fluentBit.opensearchPort" 9200 isValidPort
          "Must be a valid port number (1-65535)";
    };
  };

  # 追加のアサーション
  assertions = [
    {
      assertion = config.ssh.port != 22;
      message = "SSH port should not use the default port 22 for security reasons";
    }
    {
      assertion =
        config.k3s.desktop.enable
        -> (config.k3s.desktop.role == "server" || config.k3s.desktop.role == "agent");
      message = "k3s role must be either 'server' or 'agent'";
    }
    {
      assertion =
        config.k3s.desktop.role == "agent"
        -> (builtins.hasAttr "serverAddr" config.k3s.desktop && config.k3s.desktop.serverAddr != "");
      message = "k3s agent mode requires serverAddr to be set";
    }
    {
      assertion = config.networking.firewall.generalPort != config.networking.firewall.nfsPort;
      message = "General port must be different from NFS port";
    }
    {
      assertion = config.management.cockpit.port != config.management.ttyd.port;
      message = "Cockpit port must be different from ttyd port";
    }
    {
      assertion = config.management.cockpit.port != config.monitoring.prometheus.port;
      message = "Cockpit port must be different from Prometheus port";
    }
    {
      assertion = config.management.ttyd.port != config.monitoring.grafana.port;
      message = "ttyd port must be different from Grafana port";
    }
  ];

  # アサーションのチェック
  checkedConfig = builtins.foldl' (
    acc: assertion:
    if assertion.assertion then acc else throw "Config assertion failed: ${assertion.message}"
  ) config assertions;
in
checkedConfig

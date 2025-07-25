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
  isValidEmail = email: builtins.match ''^[^@]+@[^@]+'' email != null;

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

      # ファイアウォール設定
      firewall = {
        generalPort =
          assertType "networking.firewall.generalPort" 8888 isValidPort
            "Must be a valid port number (1-65535)";
        kubernetesApiPort =
          assertType "networking.firewall.kubernetesApiPort" 6443 isValidPort
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

    # Kubernetes設定
    kubernetes = {
      master = {
        ip = assertType "kubernetes.master.ip" "192.168.1.3" isValidIP "Must be a valid IP address";
        hostname = assertType "kubernetes.master.hostname" "api.kube" builtins.isString "Must be a string";
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
    };
  };

  # 追加のアサーション
  assertions = [
    {
      assertion = config.networking.firewall.kubernetesApiPort != config.networking.firewall.generalPort;
      message = "Kubernetes API port must be different from general port";
    }
    {
      assertion = config.ssh.port != 22;
      message = "SSH port should not use the default port 22 for security reasons";
    }
    {
      assertion = config.networking.firewall.generalPort != config.networking.firewall.nfsPort;
      message = "General port must be different from NFS port";
    }
    {
      assertion = config.networking.firewall.kubernetesApiPort != config.networking.firewall.nfsPort;
      message = "Kubernetes API port must be different from NFS port";
    }
  ];

  # アサーションのチェック
  checkedConfig = builtins.foldl' (
    acc: assertion:
    if assertion.assertion then acc else throw "Config assertion failed: ${assertion.message}"
  ) config assertions;
in
checkedConfig

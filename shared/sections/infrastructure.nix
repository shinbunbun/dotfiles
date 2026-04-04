/*
  インフラストラクチャ設定セクション

  k3s、NFS、Atticバイナリキャッシュ、peer-issuer、
  OpenSearch、OpenSearch Dashboards、Fluent Bitの設定を定義します。
*/
v: {
  k3s = {
    # クラスタ共通設定
    cluster = {
      vip = v.assertIP "k3s.cluster.vip" "192.168.1.254";
      apiPort = v.assertPort "k3s.cluster.apiPort" 6443;
      apiBackendPort = v.assertPort "k3s.cluster.apiBackendPort" 6444;
      serviceCIDR = v.assertCIDR "k3s.cluster.serviceCIDR" "192.168.128.0/24";
      servicePool = v.assertString "k3s.cluster.servicePool" "192.168.128.100-192.168.128.200";
      traefikVIP = v.assertIP "k3s.cluster.traefikVIP" "192.168.128.10";
      podCIDR = v.assertCIDR "k3s.cluster.podCIDR" "10.42.0.0/16";
      bgp = {
        localAS = v.assertPositiveInt "k3s.cluster.bgp.localAS" 65001;
        peerAS = v.assertPositiveInt "k3s.cluster.bgp.peerAS" 65000;
        peerAddress = v.assertIP "k3s.cluster.bgp.peerAddress" "192.168.1.1";
      };
    };

    # 共通のk3sフラグ（Cilium用）
    commonExtraFlags = [
      "--flannel-backend=none"
      "--disable-kube-proxy"
      "--disable-network-policy"
      "--disable=servicelb"
      "--write-kubeconfig-mode=0644"
    ];

    # nixos-desktop: 初期化ノード
    desktop = {
      enable = v.assertBool "k3s.desktop.enable" true;
      role = v.assertEnum "k3s.desktop.role" "server" [
        "server"
        "agent"
      ];
      clusterInit = v.assertBool "k3s.desktop.clusterInit" true;
      keepalivedPriority = v.assertPositiveInt "k3s.desktop.keepalivedPriority" 150;
      extraFlags = [
        "--node-ip=192.168.1.4"
        "--kubelet-arg=housekeeping-interval=30s"
      ];
    };

    # homeMachine: 参加ノード
    homeMachine = {
      enable = v.assertBool "k3s.homeMachine.enable" true;
      role = v.assertEnum "k3s.homeMachine.role" "server" [
        "server"
        "agent"
      ];
      keepalivedPriority = v.assertPositiveInt "k3s.homeMachine.keepalivedPriority" 100;
      extraFlags = [
        "--node-ip=192.168.1.3"
        "--kubelet-arg=housekeeping-interval=30s"
      ];
    };

    # g3pro: 参加ノード
    g3pro = {
      enable = v.assertBool "k3s.g3pro.enable" true;
      role = v.assertEnum "k3s.g3pro.role" "server" [
        "server"
        "agent"
      ];
      keepalivedPriority = v.assertPositiveInt "k3s.g3pro.keepalivedPriority" 50;
      extraFlags = [
        "--node-ip=192.168.1.6"
        "--kubelet-arg=housekeeping-interval=30s"
      ];
    };
  };

  nfs = {
    exportPath = v.assertPath "nfs.exportPath" "/export/k8s";
    clients = [
      { ip = v.assertIP "nfs.clients[0].ip" "192.168.1.3"; }
      { ip = v.assertIP "nfs.clients[1].ip" "192.168.1.4"; }
    ];
    options = v.assertString "nfs.options" "rw,nohide,insecure,no_subtree_check,no_root_squash";
  };

  samba = {
    enable = v.assertBool "samba.enable" false;
    workgroup = v.assertString "samba.workgroup" "WORKGROUP";
    serverString = v.assertString "samba.serverString" "NixOS NAS";
    keepalive = v.assertNonNegativeInt "samba.keepalive" 60;
    deadTime = v.assertNonNegativeInt "samba.deadTime" 0;
    serverMultiChannelSupport = v.assertBool "samba.serverMultiChannelSupport" false;
  };

  attic = {
    port = v.assertPort "attic.port" 8080;
    domain = v.assertString "attic.domain" "cache.shinbunbun.com";

    # ストレージ設定
    storagePath = v.assertPath "attic.storagePath" "/var/lib/atticd/storage";

    # データベース設定
    database = {
      name = v.assertString "attic.database.name" "attic";
      user = v.assertString "attic.database.user" "attic";
    };

    # ガベージコレクション設定
    garbageCollection = {
      interval = v.assertString "attic.garbageCollection.interval" "12 hours";
      retentionPeriod = v.assertString "attic.garbageCollection.retentionPeriod" "30 days";
    };

    # チャンク設定
    chunking = {
      narSizeThreshold = v.assertPositiveInt "attic.chunking.narSizeThreshold" 131072; # 128 KiB
      minSize = v.assertPositiveInt "attic.chunking.minSize" 32768; # 32 KiB
      avgSize = v.assertPositiveInt "attic.chunking.avgSize" 131072; # 128 KiB
      maxSize = v.assertPositiveInt "attic.chunking.maxSize" 524288; # 512 KiB
    };

    # 圧縮設定
    compression = {
      type = v.assertString "attic.compression.type" "zstd";
      level = v.assertType "attic.compression.level" 3 (
        n: builtins.isInt n && n >= 1 && n <= 22
      ) "Must be an integer between 1 and 22";
    };
  };

  peerIssuer = {
    domain = v.assertString "peerIssuer.domain" "wg-lease.shinbunbun.com";
    listenAddr = v.assertString "peerIssuer.listenAddr" "0.0.0.0:8088";
    listenPort = v.assertPort "peerIssuer.listenPort" 8088;
    dbPath = v.assertPath "peerIssuer.dbPath" "/var/lib/peer-issuer/leases.db";
    poolCIDR = v.assertCIDR "peerIssuer.poolCIDR" "10.66.66.64/26";
    routerHost = v.assertIP "peerIssuer.routerHost" "192.168.1.1";
    routerPort = v.assertPort "peerIssuer.routerPort" 22;
    routerUser = v.assertString "peerIssuer.routerUser" "wgissuer";
    routerWgInterface = v.assertString "peerIssuer.routerWgInterface" "wg-home";
    wgMTU = v.assertPositiveInt "peerIssuer.wgMTU" 1392;
    wgKeepalive = v.assertPositiveInt "peerIssuer.wgKeepalive" 25;
    defaultTTL = v.assertPositiveInt "peerIssuer.defaultTTL" 86400;
    stateDirectory = v.assertPath "peerIssuer.stateDirectory" "/var/lib/peer-issuer";
  };

  opensearch = {
    # サーバー設定
    port = v.assertPort "opensearch.port" 9200;
    transportPort = v.assertPort "opensearch.transportPort" 9300;
    dataDir = v.assertPath "opensearch.dataDir" "/var/lib/opensearch";

    # メモリ設定（ヒープ4GB + Off-heap用4GB = 合計8GB）
    heapSize = v.assertString "opensearch.heapSize" "4g";
    maxMemory = v.assertPositiveInt "opensearch.maxMemory" 8589934592; # 4GB heap + 4GB off-heap = 8GB

    # クラスター設定
    clusterName = v.assertString "opensearch.clusterName" "shinbunbun-logs";
    nodeName = v.assertString "opensearch.nodeName" "nixos-desktop";

    # インデックス設定
    numberOfShards = v.assertPositiveInt "opensearch.numberOfShards" 1; # 単一ノードのため
    numberOfReplicas = v.assertNonNegativeInt "opensearch.numberOfReplicas" 0; # レプリカ不要

    # セキュリティ設定
    enableSecurity = v.assertBool "opensearch.enableSecurity" true;
    allowedNetworks = v.assertListOf "opensearch.allowedNetworks" [
      "192.168.1.0/24"
      "192.168.11.0/24"
      "10.66.66.0/24" # WireGuard
    ] v.assertCIDR;
  };

  opensearchDashboards = {
    port = v.assertPort "opensearchDashboards.port" 5601;
    domain = v.assertString "opensearchDashboards.domain" "opensearch.shinbunbun.com";
    opensearchUrl = v.assertString "opensearchDashboards.opensearchUrl" "http://192.168.1.4:9200";
  };

  fluentBit = {
    port = v.assertPort "fluentBit.port" 2020;
    syslogPort = v.assertPort "fluentBit.syslogPort" 514;
    opensearchHost = v.assertIP "fluentBit.opensearchHost" "192.168.1.4";
    opensearchPort = v.assertPort "fluentBit.opensearchPort" 9200;
    k3sPodLogDir = v.assertPath "fluentBit.k3sPodLogDir" "/var/log/pods";
  };
}

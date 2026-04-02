/*
  k3s HAクラスタ設定モジュール

  このモジュールは3ノードHA構成のk3sクラスタを提供します。

  コンポーネント:
  - k3s server: embedded etcd による HAクラスタ（3ノード）
  - HAProxy: API Server ロードバランシング（:6443 → :6444）
  - keepalived: VRRP による API Server VIP 管理
  - Cilium: CNI + kube-proxy代替 + BGP Service LB（別途Helmでインストール）
  - DRBD: カーネルレベルストレージレプリケーション（Piraeus Operator経由で管理）

  ネットワーク設計:
  - API Server VIP: 192.168.1.254 (keepalived VRRP)
  - Service VIP: 192.168.128.0/24 (Cilium BGP → RouterOS ECMP)
  - Pod CIDR: 10.42.0.0/16 (Cilium IPAM)

  使用方法:
  1. 各ホストのNixOS設定でこのモジュールをimport
  2. shared/config.nixでk3s設定を定義
  3. nixos-rebuild switchで適用
  4. 初回はnixos-desktopから起動し、他ノードが順次join
*/
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = import ../../../shared/config.nix;

  # ホスト名でk3s設定を選択
  k3sConfig =
    if config.networking.hostName == cfg.networking.hosts.nixosDesktop.hostname then
      cfg.k3s.desktop
    else if config.networking.hostName == cfg.networking.hosts.nixos.hostname then
      cfg.k3s.homeMachine
    else if config.networking.hostName == cfg.networking.hosts.g3pro.hostname then
      cfg.k3s.g3pro
    else
      { enable = false; };

  enable = k3sConfig.enable or false;
  role = k3sConfig.role or "server";
  clusterInit = k3sConfig.clusterInit or false;
  keepalivedPriority = k3sConfig.keepalivedPriority or 50;

  clusterCfg = cfg.k3s.cluster;

  # k3sフラグを結合（共通 + ノード固有 + HA固有）
  haFlags = [
    "--https-listen-port=${toString clusterCfg.apiBackendPort}"
    "--tls-san=${clusterCfg.vip}"
  ];

  serverAddrFlags =
    if clusterInit then
      [ ]
    else
      [ "--server=https://${clusterCfg.vip}:${toString clusterCfg.apiPort}" ];

  allExtraFlags =
    cfg.k3s.commonExtraFlags ++ haFlags ++ serverAddrFlags ++ (k3sConfig.extraFlags or [ ]);

  # 監視用RBACマニフェスト
  monitoringRbacConfig = pkgs.writeText "monitoring-rbac.yaml" ''
    apiVersion: v1
    kind: Namespace
    metadata:
      name: monitoring
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: monitoring-sa
      namespace: monitoring
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: monitoring-reader
    rules:
      - apiGroups: [""]
        resources:
          - nodes
          - nodes/metrics
          - nodes/proxy
          - services
          - endpoints
          - pods
        verbs: ["get", "list", "watch"]
      - apiGroups: ["apps"]
        resources:
          - deployments
          - replicasets
          - statefulsets
          - daemonsets
        verbs: ["get", "list", "watch"]
      - apiGroups: ["batch"]
        resources:
          - jobs
          - cronjobs
        verbs: ["get", "list", "watch"]
      - nonResourceURLs:
          - /metrics
          - /metrics/cadvisor
        verbs: ["get"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: monitoring-reader-binding
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: monitoring-reader
    subjects:
      - kind: ServiceAccount
        name: monitoring-sa
        namespace: monitoring
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: monitoring-sa-token
      namespace: monitoring
      annotations:
        kubernetes.io/service-account.name: monitoring-sa
    type: kubernetes.io/service-account-token
  '';

  # Traefik HelmChartConfig
  traefikConfig = pkgs.writeText "traefik-config.yaml" ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChartConfig
    metadata:
      name: traefik
      namespace: kube-system
    spec:
      valuesContent: |-
        hub:
          enabled: false
        providers:
          kubernetesGateway:
            enabled: false
  '';

  # HAProxy設定
  haproxyConfig = ''
    global
        log /dev/log local0
        maxconn 2048

    defaults
        log     global
        mode    tcp
        option  tcplog
        timeout connect 5s
        timeout client  30s
        timeout server  30s

    frontend k8s-api
        bind *:${toString clusterCfg.apiPort}
        default_backend k8s-api-servers

    backend k8s-api-servers
        option httpchk GET /healthz
        http-check expect status 200
        balance roundrobin
        server nixos-desktop ${cfg.networking.hosts.nixosDesktop.ip}:${toString clusterCfg.apiBackendPort} check check-ssl verify none inter 3s fall 3 rise 2
        server homemachine 192.168.1.3:${toString clusterCfg.apiBackendPort} check check-ssl verify none inter 3s fall 3 rise 2
        server g3pro ${cfg.networking.hosts.g3pro.ip}:${toString clusterCfg.apiBackendPort} check check-ssl verify none inter 3s fall 3 rise 2
  '';

  # keepalivedのユニキャストピア（自分以外のノード）
  allNodeIPs = [
    cfg.networking.hosts.nixosDesktop.ip
    "192.168.1.3"
    cfg.networking.hosts.g3pro.ip
  ];
  myIP =
    if config.networking.hostName == cfg.networking.hosts.nixosDesktop.hostname then
      cfg.networking.hosts.nixosDesktop.ip
    else if config.networking.hostName == cfg.networking.hosts.nixos.hostname then
      "192.168.1.3"
    else
      cfg.networking.hosts.g3pro.ip;
  unicastPeers = builtins.filter (ip: ip != myIP) allNodeIPs;

  # ネットワークインターフェース（ホストごとに異なる可能性）
  keepalivedInterface =
    if config.networking.hostName == cfg.networking.hosts.nixosDesktop.hostname then
      "enp2s0"
    else if config.networking.hostName == cfg.networking.hosts.nixos.hostname then
      cfg.networking.interfaces.primary
    else
      "enp1s0";
in
{
  config = lib.mkIf enable {
    # k3sサービスの設定
    services.k3s = {
      enable = true;
      inherit role;
      clusterInit = lib.mkIf (role == "server") clusterInit;
      # clusterInit でないノードはトークンが必要
      # sops.secrets."k3s_token" は dotfiles-private 側で定義する
      tokenFile = lib.mkIf (!clusterInit) "/run/secrets/k3s_token";
      extraFlags = lib.strings.concatStringsSep " " allExtraFlags;
    };

    # SOPS シークレット（クラスタトークン）はdotfiles-privateで定義
    # sops.secrets."k3s_token" は各ホストの設定で sopsFile を指定する必要がある

    # HAProxy: API Server ロードバランシング
    services.haproxy = {
      enable = true;
      config = haproxyConfig;
    };

    # keepalived: VRRP VIP 管理
    services.keepalived = {
      enable = true;
      vrrpScripts.check-haproxy = {
        script = "${pkgs.procps}/bin/pgrep -x haproxy";
        interval = 2;
        weight = 2;
      };
      vrrpInstances.k8s-api = {
        interface = keepalivedInterface;
        virtualRouterId = 51;
        priority = keepalivedPriority;
        virtualIps = [ { addr = "${clusterCfg.vip}/24"; } ];
        trackScripts = [ "check-haproxy" ];
        inherit unicastPeers;
      };
    };

    # k3sマニフェストディレクトリに設定ファイルを自動配置
    systemd.tmpfiles.rules = [
      "L+ /var/lib/rancher/k3s/server/manifests/traefik-config.yaml - - - - ${traefikConfig}"
      "L+ /var/lib/rancher/k3s/server/manifests/monitoring-rbac.yaml - - - - ${monitoringRbacConfig}"
    ];

    # ghcr.io認証用のregistries.yamlを動的生成するsystemdサービス
    # argocd/ghcr_pat シークレットは dotfiles-private の argocd.nix で定義されるため、
    # 初期化ノード（nixos-desktop）でのみ有効
    systemd.services.k3s-registries = lib.mkIf clusterInit {
      description = "k3s Container Registry Authentication Setup";
      before = [ "k3s.service" ];
      after = [ "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [
        pkgs.coreutils
        pkgs.systemd
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script =
        let
          ghcrPatPath = config.sops.secrets."argocd/ghcr_pat".path;
          registry = cfg.ghcr.registry;
          username = cfg.ghcr.username;
        in
        ''
          mkdir -p /etc/rancher/k3s

          GHCR_PAT=$(cat ${ghcrPatPath})
          cat > /etc/rancher/k3s/registries.yaml <<EOF
          mirrors:
            ${registry}:
              endpoint:
                - "https://${registry}"
          configs:
            "${registry}":
              auth:
                username: ${username}
                password: $GHCR_PAT
          EOF

          chmod 0600 /etc/rancher/k3s/registries.yaml

          if systemctl is-active --quiet k3s.service; then
            systemctl restart --no-block k3s.service
          fi
        '';
    };

    # k3sツールとkubectl等をシステムパスに追加
    environment.systemPackages = with pkgs; [
      k3s
      kubectl
      kubernetes-helm
      stern
    ];

    # ファイアウォール設定
    networking.firewall = {
      allowedTCPPorts = [
        clusterCfg.apiPort # HAProxy フロントエンド
        clusterCfg.apiBackendPort # k3s API Server バックエンド
        10250 # Kubelet metrics
        4240 # Cilium health check
        4244 # Hubble
        179 # BGP (Cilium ↔ RouterOS)
        3366 # LINSTOR Controller
        3367 # LINSTOR Satellite
      ];

      allowedTCPPortRanges = [
        {
          from = 2379;
          to = 2380;
        } # etcd
        {
          from = 7000;
          to = 8000;
        } # DRBD レプリケーション
      ];

      allowedUDPPorts = [
        8472 # Cilium VXLAN
      ];

      # VRRP プロトコル（keepalived）
      extraCommands = ''
        iptables -A INPUT -p vrrp -j ACCEPT
      '';
    };

    # KUBECONFIG環境変数の設定
    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    # カーネルモジュール
    # DRBD はPiraeus Operator の Module Loader が管理する
    # （nixpkgs の DRBD 9.2.16 は Linux 6.19+ で未対応のため、ホスト側ビルドは行わない）
    boot.kernelModules = [
      "br_netfilter"
      "overlay"
      # Cilium 用
      "ip_tables"
      "xt_socket"
      "xt_mark"
    ];

    # LVM thin provisioning（Piraeus/LINSTOR用）
    services.lvm.boot.thin.enable = true;

    # カーネルパラメータ（Kubernetes推奨設定）
    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
    };
  };
}

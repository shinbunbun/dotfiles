/*
  k3s HAクラスタ設定モジュール

  このモジュールは3ノードHA構成のk3sクラスタを提供します。

  コンポーネント:
  - k3s server: embedded etcd による HAクラスタ（3ノード）
  - HAProxy: API Server ロードバランシング（:6443 → :6444）
  - keepalived: VRRP による API Server VIP 管理
  - Cilium: CNI + kube-proxy代替 + BGP Service LB（k8s-apps の ArgoCD Application で管理）
  - DRBD: カーネルレベルストレージレプリケーション（Piraeus Operator経由で管理）

  CoreDNS HA:
  - k3s 1.25.5+ は CoreDNS Deployment の replicas を hardcode しないため、`kubectl scale` の値が永続化される
  - clusterInit ノード上で systemd-coredns-scale が k3s 起動後に冪等な scale を実行
  - k3s 公式マニフェストは既に topologySpreadConstraints (hostname maxSkew=1 DoNotSchedule) を持つので別ノードに分散される

  新規クラスタ初期化時の Cilium bootstrap:
  - ArgoCD は Cilium が動いていないと pod を schedule できないため、
    クラスタ初回起動時のみ手動で Cilium をインストールする必要がある
  - 手順: `helm install cilium cilium/cilium --version <ver> -n kube-system -f <values>`
  - ArgoCD が起動したら application `cilium` が ServerSideApply で既存リソースを adopt し、
    以降の管理は ArgoCD に引き継がれる

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
  inputs,
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

  # LINSTOR ストレージ設定
  linstorCfg = cfg.k3s.linstor;
  linstorNodeCfg = k3sConfig.linstor or { };
  loopFile = linstorNodeCfg.loopFile or "/var/lib/linstor-loop.img";
  loopSize = linstorNodeCfg.loopSize or "50G";
  vgName = linstorCfg.vgName;
  thinPoolName = linstorCfg.thinPoolName;

  clusterCfg = cfg.k3s.cluster;

  # このホストの IP（networking.hosts を単一情報源とする）。
  # infrastructure.nix の extraFlags には --node-ip を持たせず、ここで
  # networking.hosts.*.ip から導出して付与する（IP の二重定義解消）。
  nodeIP =
    if config.networking.hostName == cfg.networking.hosts.nixosDesktop.hostname then
      cfg.networking.hosts.nixosDesktop.ip
    else if config.networking.hostName == cfg.networking.hosts.nixos.hostname then
      cfg.networking.hosts.nixos.ip
    else if config.networking.hostName == cfg.networking.hosts.g3pro.hostname then
      cfg.networking.hosts.g3pro.ip
    else
      throw "k3s.nix: networking.hosts に hostName '${config.networking.hostName}' の IP 定義がありません";

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

  nodeIPFlags = [ "--node-ip=${nodeIP}" ];

  # etcd メトリクスを :2381 平文HTTP（認証なし）で公開する。vmagent（k3s Pod、Pod
  # ネットワークから各ノード IP:2381 へアクセス）が etcd_disk_wal_fsync_duration_seconds
  # 等をスクレイプできるようにする。dotfiles-private#398 で etcd fsync 停滞が k3s 全断の
  # 根因だったにもかかわらず etcd メトリクスが公開されておらず診断できなかったギャップへの
  # 対応（unified-dotfiles#34）。embedded etcd member である server role のときのみ意味を
  # 持つため role == "server" でのみ付与する（3ノードとも現状 server だが将来 agent が
  # 増えても安全なようにガードする）。
  etcdMetricsFlags = lib.optionals (role == "server") [ "--etcd-expose-metrics" ];

  allExtraFlags =
    cfg.k3s.commonExtraFlags
    ++ haFlags
    ++ serverAddrFlags
    ++ nodeIPFlags
    ++ etcdMetricsFlags
    ++ (k3sConfig.extraFlags or [ ]);

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
        option tcp-check
        balance roundrobin
        default-server inter 3s fall 3 rise 2
        server nixos-desktop ${cfg.networking.hosts.nixosDesktop.ip}:${toString clusterCfg.apiBackendPort} check
        server homemachine ${cfg.networking.hosts.nixos.ip}:${toString clusterCfg.apiBackendPort} check
        server g3pro ${cfg.networking.hosts.g3pro.ip}:${toString clusterCfg.apiBackendPort} check
  '';

  # keepalivedのユニキャストピア（自分以外のノード）
  allNodeIPs = [
    cfg.networking.hosts.nixosDesktop.ip
    cfg.networking.hosts.nixos.ip
    cfg.networking.hosts.g3pro.ip
  ];
  # 自ノードの IP は nodeIP（--node-ip と同一の導出）を再利用する
  unicastPeers = builtins.filter (ip: ip != nodeIP) allNodeIPs;

  # ネットワークインターフェース（ホストごとに異なる）
  keepalivedInterface =
    if config.networking.hostName == cfg.networking.hosts.nixosDesktop.hostname then
      cfg.networking.interfaces.nixosDesktop.primary
    else if config.networking.hostName == cfg.networking.hosts.nixos.hostname then
      cfg.networking.interfaces.homeMachine.primary
    else
      cfg.networking.interfaces.g3pro.primary;
in
{
  config = lib.mkIf enable {
    # k3sサービスの設定
    services.k3s = {
      enable = true;
      inherit role;
      clusterInit = lib.mkIf (role == "server") clusterInit;
      tokenFile = lib.mkIf (!clusterInit) config.sops.secrets."k3s_token".path;
      extraFlags = lib.strings.concatStringsSep " " allExtraFlags;
    };

    # SOPS シークレット（クラスタトークン — join ノード用）
    sops.secrets."k3s_token" = lib.mkIf (!clusterInit) {
      sopsFile = "${inputs.self}/secrets/k3s.yaml";
    };

    # HAProxy: API Server ロードバランシング
    services.haproxy = {
      enable = true;
      config = haproxyConfig;
    };

    # keepalived: VRRP VIP 管理
    # keepalived_script ユーザー（vrrpScripts 実行用）
    users.users.keepalived_script = {
      isSystemUser = true;
      group = "keepalived_script";
    };
    users.groups.keepalived_script = { };

    services.keepalived = {
      enable = true;
      vrrpScripts.check-haproxy = {
        script = "${pkgs.procps}/bin/pgrep -x haproxy";
        interval = 2;
        weight = 2;
        user = "keepalived_script";
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
    # Cilium は ArgoCD で管理するため、ここでは配置しない
    # （新規クラスタ初期化時のみ手動で helm install が必要。モジュール冒頭コメント参照）
    #
    # `r` で traefik-config.yaml を削除しているのは、Traefik 撤廃時に `L+` ルールを
    # 消しても symlink 実体が /var/lib に残り、nix GC でリンク先が消えて dangling 化
    # したため（systemd-tmpfiles は symlink の作成・更新しかせず、ルール消滅による
    # 削除はしない）。k3s の deploy watcher はこのディレクトリを走査する際に symlink を
    # os.Stat するため、dangling が 1 本あるだけで走査全体が中断し、auto-deploy が
    # 丸ごと停止する（15 秒ごとに "Failed to process config: stat ..." を出し続ける）。
    # `r` は対象が存在しなければ no-op なので、新規ノードでも安全。
    systemd.tmpfiles.rules = [
      "r /var/lib/rancher/k3s/server/manifests/traefik-config.yaml"
      "L+ /var/lib/rancher/k3s/server/manifests/monitoring-rbac.yaml - - - - ${monitoringRbacConfig}"
    ];

    # ghcr.io 認証用の registries.yaml を動的生成する systemd サービス。
    # 全 k3s ノードで有効化し、private な ghcr イメージをどのノードに載っても pull
    # できるようにする。ノード限定認証（旧: clusterInit のみ）だと、未認証ノードへ
    # スケジュールされた Pod が匿名 pull にフォールバックして 401 ImagePullBackOff で
    # 失敗する（2026-07-13 g3pro での CronJob 全滅の根因）。
    # PAT の供給元はノード種別で異なる（どちらも同一の read-only pull PAT）:
    #   - clusterInit ノード（nixos-desktop）: dotfiles-private の argocd/ghcr_pat
    #   - join ノード（g3pro/homemachine, dotfiles）: dotfiles/secrets/ghcr.yaml の ghcr/pull_pat
    sops.secrets."ghcr/pull_pat" = lib.mkIf (!clusterInit) {
      sopsFile = "${inputs.self}/secrets/ghcr.yaml";
    };

    systemd.services.k3s-registries = lib.mkIf enable {
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
          ghcrPatPath =
            if clusterInit then
              config.sops.secrets."argocd/ghcr_pat".path
            else
              config.sops.secrets."ghcr/pull_pat".path;
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

    # CoreDNS HA: clusterInit ノードで k3s 起動後に replicas を冪等に scale する
    # k3s 1.25.5+ (PR #6552) は CoreDNS Deployment の replicas を hardcode しないため、
    # kubectl scale の値は再起動後も保持される。boot 毎にこのユニットが reconcile する
    systemd.services.k3s-coredns-scale = lib.mkIf clusterInit {
      description = "Persist CoreDNS replicas across k3s restarts";
      after = [ "k3s.service" ];
      wants = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [
        pkgs.k3s
        pkgs.coreutils
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "30s";
        TimeoutStartSec = "600";
      };

      script = ''
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        until k3s kubectl cluster-info >/dev/null 2>&1; do
          sleep 5
        done
        until k3s kubectl -n kube-system get deploy coredns >/dev/null 2>&1; do
          sleep 5
        done
        k3s kubectl -n kube-system scale deploy/coredns \
          --replicas=${toString clusterCfg.coredns.replicas}
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
        2381 # etcd メトリクス（平文HTTP・認証なし、--etcd-expose-metrics）。vmagent がスクレイプ。LAN 内限定
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
        } # etcd (peer/client)
        {
          from = 7000;
          to = 8000;
        } # DRBD レプリケーション
      ];

      allowedUDPPorts = [
        8472 # Cilium VXLAN
      ];

      # Cilium/k3s 関連のインターフェースを信頼
      trustedInterfaces = [
        "cilium_host"
        "cilium_net"
        "cilium_vxlan"
        "lxc+"
      ];

      # Cilium: rpfilter を loose に（Pod からの返信パケットが DROP されるのを防ぐ）
      checkReversePath = "loose";

      # VRRP プロトコル（keepalived）+ Pod ネットワーク許可
      extraCommands = ''
        iptables -A INPUT -p vrrp -j ACCEPT
        iptables -A INPUT -s ${clusterCfg.podCIDR} -j ACCEPT
      '';
    };

    # KUBECONFIG環境変数の設定
    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    # カーネルモジュール
    boot.kernelModules = [
      "br_netfilter"
      "overlay"
      # Cilium 用
      "ip_tables"
      "xt_socket"
      "xt_mark"
      # LVM thin provisioning 用（LINSTOR/Piraeus）
      "dm-thin-pool"
      # DRBD 9（Piraeus/LINSTOR 用）
      # ホスト側でプリロードし、Piraeus の drbd-module-loader はビルドをスキップする
      "drbd"
    ];

    # DRBD 9 out-of-tree モジュール（Piraeus/LINSTOR 用）
    # in-tree の DRBD 8.4.11 ではなく out-of-tree の 9.2.x を使用
    # depmod は updates/ を kernel/ より優先するため、9.x が自動的に選択される
    boot.extraModulePackages = with config.boot.kernelPackages; [ drbd ];

    # LVM thin provisioning（Piraeus/LINSTOR用）
    services.lvm.boot.thin.enable = true;

    # LINSTOR ストレージ用 loop device + LVM thin pool セットアップ
    #
    # 各ノードの空きディスク領域にファイルベースの loop device を作成し、
    # その上に LVM VG + thin pool を構築する。Piraeus satellite が
    # このストレージプールを使用して DRBD ボリュームを管理する。
    # k3s 起動前に完了させる必要がある。
    systemd.services.linstor-loop-setup = {
      description = "LINSTOR loop device and LVM thin pool setup";
      wantedBy = [ "multi-user.target" ];
      before = [ "k3s.service" ];
      after = [
        "local-fs.target"
        "lvm2-monitor.service"
        "systemd-modules-load.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = with pkgs; [
        util-linux
        lvm2
        coreutils
      ];
      script = ''
        set -euo pipefail

        LOOP_FILE="${loopFile}"
        LOOP_SIZE="${loopSize}"
        VG_NAME="${vgName}"
        TP_NAME="${thinPoolName}"

        # loop ファイル作成（存在しない場合のみ）
        if [ ! -f "$LOOP_FILE" ]; then
          echo "Creating loop file: $LOOP_FILE ($LOOP_SIZE)"
          truncate -s "$LOOP_SIZE" "$LOOP_FILE"
        fi

        # 既に loop device がアタッチされているか確認
        LOOP_DEV=$(losetup -j "$LOOP_FILE" | head -1 | cut -d: -f1)
        if [ -z "$LOOP_DEV" ]; then
          echo "Attaching loop device for $LOOP_FILE"
          LOOP_DEV=$(losetup --show -f "$LOOP_FILE")
          echo "Attached as $LOOP_DEV"
        else
          echo "Already attached: $LOOP_DEV"
        fi

        # LVM PV 作成（未作成の場合のみ）
        if ! pvs "$LOOP_DEV" &>/dev/null; then
          echo "Creating PV on $LOOP_DEV"
          pvcreate "$LOOP_DEV"
        fi

        # VG 作成（未作成の場合のみ）
        if ! vgs "$VG_NAME" &>/dev/null; then
          echo "Creating VG: $VG_NAME"
          vgcreate "$VG_NAME" "$LOOP_DEV"
        else
          # VG が非アクティブの場合にアクティベート
          vgchange -ay "$VG_NAME"
        fi

        # Thin pool 作成（未作成の場合のみ）
        if ! lvs "$VG_NAME/$TP_NAME" &>/dev/null; then
          echo "Creating thin pool: $VG_NAME/$TP_NAME"
          lvcreate -l 100%FREE -T "$VG_NAME/$TP_NAME"
        fi

        echo "LINSTOR storage ready: $VG_NAME/$TP_NAME on $LOOP_DEV"
      '';
    };

    # カーネルパラメータ（Kubernetes推奨設定）
    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
      # Pyroscope eBPF profiler が /proc/kallsyms から kernel symbol を解決して
      # flame graph に kernel frame (entry_SYSCALL_64 等) を表示するために必要。
      # k8s-apps/infrastructure/alloy-profiles の pyroscope.ebpf component が
      # collect_kernel_profile: true (default) で kernel stack を採取する際、
      # kptr_restrict=1/2 では kallsyms のアドレスが 0 になり symbol 解決不可。
      # LAN-only + single-user 環境前提で KASLR 無効化リスクは許容。
      # Issue: shinbunbun/dotfiles#699
      "kernel.kptr_restrict" = 0;
    };
  };
}

/*
  k3s（Lightweight Kubernetes）設定モジュール

  このモジュールはk3sを使用した軽量Kubernetesクラスタを提供します。

  機能:
  - k3sサーバーモード: 完全なKubernetesクラスタをホスト
  - k3sエージェントモード: 既存のクラスタにワーカーノードとして参加
  - containerdコンテナランタイム（Dockerとは独立して動作）
  - Flannelネットワーキング（VXLAN）
  - CoreDNS（DNSサービス）
  - Traefik Ingressコントローラー（デフォルト）

  提供する設定:
  - services.k3s.enable: k3sサービスの有効化
  - services.k3s.role: "server"または"agent"
  - services.k3s.clusterInit: 初回クラスタ初期化フラグ
  - services.k3s.extraFlags: 追加のk3sフラグ

  使用方法:
  1. shared/config.nixでkubernetes.k3s.desktop.enableをtrueに設定
  2. roleを"server"または"agent"に設定
  3. サーバーモードの場合、clusterInitをtrueに設定
  4. nixos-rebuildでシステムを再構築
  5. /etc/rancher/k3s/k3s.yamlにkubeconfigが生成される

  注意事項:
  - k3sはDockerとは独立したcontainerdを使用
  - 初回起動時に/var/lib/rancher/k3s/server/node-tokenが生成される
  - KUBECONFIG環境変数は自動的に/etc/rancher/k3s/k3s.yamlに設定される
  - ファイアウォールで必要なポート（6443, 8472等）を自動的に開放
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
    else
      { enable = false; };

  enable = k3sConfig.enable or false;
  role = k3sConfig.role or "server";
  clusterInit = k3sConfig.clusterInit or false;
  extraFlags = k3sConfig.extraFlags or [ ];
in
{
  config = lib.mkIf enable {
    # k3sサービスの設定
    services.k3s = {
      enable = true;
      inherit role;

      # サーバーモード: クラスタ初期化
      clusterInit = lib.mkIf (role == "server") clusterInit;

      # 追加フラグ
      extraFlags = lib.strings.concatStringsSep " " extraFlags;
    };

    # ghcr.io認証用のregistries.yamlを動的生成するsystemdサービス
    # k3sのcontainerdレベルでレジストリ認証を設定し、ImagePullSecretを不要にする
    # SOPSシークレット定義はargocd.nixモジュールで行う
    systemd.services.k3s-registries = {
      description = "k3s Container Registry Authentication Setup";
      before = [ "k3s.service" ];
      after = [ "sops-nix.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.coreutils ];

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
      # k3sサーバーモード用ポート
      allowedTCPPorts = lib.mkIf (role == "server") [
        6443 # Kubernetes API Server
        10250 # Kubelet metrics
      ];

      # k3s内部通信用ポート範囲
      allowedTCPPortRanges = [
        {
          from = 2379;
          to = 2380;
        } # etcd
      ];

      # Flannel VXLAN
      allowedUDPPorts = [
        8472 # Flannel VXLAN
      ];
    };

    # KUBECONFIG環境変数の設定
    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };

    # k3s用のカーネルモジュール
    boot.kernelModules = [
      "br_netfilter"
      "overlay"
    ];

    # カーネルパラメータ（Kubernetes推奨設定）
    boot.kernel.sysctl = {
      "net.bridge.bridge-nf-call-iptables" = 1;
      "net.bridge.bridge-nf-call-ip6tables" = 1;
      "net.ipv4.ip_forward" = 1;
    };
  };
}

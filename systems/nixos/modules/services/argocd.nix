/*
  ArgoCD GitOps デプロイメント設定モジュール

  このモジュールはk3sクラスタ上にArgoCDをデプロイします：
  - k3s HelmChart CRDを使用したArgoCD Helm chartの自動デプロイ
  - Traefik IngressRouteによるHTTPルーティング
  - SOPS統合によるOIDCクレデンシャルの安全な管理
  - GitHub Deploy Keyの自動投入（k8s-appsリポジトリアクセス用）
  - Authentik OIDCによるSSO認証
  - グループベースのRBAC（ArgoCD Admins / ArgoCD Users）

  使用方法:
  1. dotfiles-privateのnixos-desktop設定でこのモジュールをimport
  2. secrets/argocd.yamlにOIDCクレデンシャルとDeploy Keyを設定
  3. nixos-rebuildでデプロイ
  4. https://argocd.shinbunbun.com でアクセス

  前提条件:
  - k3sサービスが有効であること
  - Cloudflare Tunnelが設定済みであること
  - Authentik OIDCプロバイダーが設定済みであること
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
  argocdCfg = cfg.argocd;
  authentikCfg = cfg.authentik;

  # ArgoCD Helm chart の values を YAML 文字列として生成
  helmValues = builtins.toJSON {
    # グローバル設定
    global = {
      domain = argocdCfg.domain;
    };

    # ArgoCD Server 設定
    server = {
      extraArgs = [ "--insecure" ]; # Traefik が TLS 終端するため
    };

    # ArgoCD Config (argocd-cm ConfigMap)
    configs = {
      cm = {
        url = "https://${argocdCfg.domain}";
        # Dex を無効化（外部 OIDC を直接使用）
        "dex.config" = "";
        # OIDC 設定
        "oidc.config" = builtins.toJSON {
          name = "Authentik";
          issuer = "${authentikCfg.baseUrl}/application/o/argocd/";
          clientID = "$oidc.authentik.clientID";
          clientSecret = "$oidc.authentik.clientSecret";
          requestedScopes = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
        };
      };

      # RBAC 設定
      rbac = {
        "policy.csv" = ''
          p, role:app-manager, applications, get, */*, allow
          p, role:app-manager, applications, create, */*, allow
          p, role:app-manager, applications, update, */*, allow
          p, role:app-manager, applications, delete, */*, allow
          p, role:app-manager, applications, sync, */*, allow
          p, role:app-manager, applications, action/*, */*, allow
          p, role:app-manager, logs, get, */*, allow
          p, role:app-manager, projects, get, *, allow
          g, ArgoCD Admins, role:admin
          g, ArgoCD Users, role:app-manager
        '';
        "policy.default" = "role:readonly";
        "scopes" = "[groups]";
      };

      # パラメータ設定
      params = {
        # Traefik が TLS 終端するため insecure モード
        "server.insecure" = true;
      };
    };

    # Dex を無効化（Authentik OIDC を直接使用）
    dex = {
      enabled = false;
    };

    # Notifications を無効化（不要）
    notifications = {
      enabled = false;
    };
  };

  # HelmChart CRD マニフェスト
  helmChartManifest = ''
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: argocd
      namespace: kube-system
    spec:
      repo: https://argoproj.github.io/argo-helm
      chart: argo-cd
      version: "${argocdCfg.helmChartVersion}"
      targetNamespace: ${argocdCfg.namespace}
      createNamespace: true
      valuesContent: |-
        ${builtins.replaceStrings [ "\n" ] [ "\n        " ] helmValues}
  '';

  # Traefik IngressRoute マニフェスト
  ingressRouteManifest = ''
    apiVersion: traefik.io/v1alpha1
    kind: IngressRoute
    metadata:
      name: argocd-server
      namespace: ${argocdCfg.namespace}
    spec:
      entryPoints:
        - web
      routes:
        - match: Host(`${argocdCfg.domain}`)
          kind: Rule
          services:
            - name: argocd-server
              port: 80
  '';
in
{
  # k3s マニフェスト配置（/var/lib/rancher/k3s/server/manifests/ に配置して k3s が自動適用）
  systemd.tmpfiles.rules = [
    "L+ /var/lib/rancher/k3s/server/manifests/argocd.yaml - - - - ${pkgs.writeText "argocd.yaml" helmChartManifest}"
    "L+ /var/lib/rancher/k3s/server/manifests/argocd-ingress.yaml - - - - ${pkgs.writeText "argocd-ingress.yaml" ingressRouteManifest}"
  ];

  # SOPS シークレット定義
  sops.secrets = {
    "argocd/oidc_client_id" = {
      sopsFile = "${inputs.self}/secrets/argocd.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "argocd/oidc_client_secret" = {
      sopsFile = "${inputs.self}/secrets/argocd.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "argocd/github_deploy_key" = {
      sopsFile = "${inputs.self}/secrets/argocd.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };

  # Kubernetes Secret 投入用 systemd サービス
  systemd.services.argocd-secrets = {
    description = "ArgoCD Kubernetes Secrets Setup";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [
      pkgs.kubectl
      pkgs.coreutils
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "30s";
      # タイムアウト：k3s起動待ちを含むため長めに設定
      TimeoutStartSec = "600";
    };

    script =
      let
        oidcClientIdPath = config.sops.secrets."argocd/oidc_client_id".path;
        oidcClientSecretPath = config.sops.secrets."argocd/oidc_client_secret".path;
        deployKeyPath = config.sops.secrets."argocd/github_deploy_key".path;
      in
      ''
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

        # k3s API サーバーが起動するまで待機
        echo "Waiting for k3s API server..."
        until kubectl cluster-info >/dev/null 2>&1; do
          sleep 5
        done

        # ArgoCD namespace が作成されるまで待機
        echo "Waiting for ArgoCD namespace..."
        until kubectl get ns ${argocdCfg.namespace} >/dev/null 2>&1; do
          sleep 5
        done

        # ArgoCD Server が起動するまで待機
        echo "Waiting for ArgoCD server deployment..."
        until kubectl -n ${argocdCfg.namespace} get deploy argocd-server >/dev/null 2>&1; do
          sleep 10
        done

        # OIDC クレデンシャルを argocd-secret に追加
        echo "Applying OIDC credentials..."
        OIDC_CLIENT_ID=$(cat ${oidcClientIdPath})
        OIDC_CLIENT_SECRET=$(cat ${oidcClientSecretPath})

        kubectl -n ${argocdCfg.namespace} create secret generic argocd-secret \
          --from-literal=oidc.authentik.clientID="$OIDC_CLIENT_ID" \
          --from-literal=oidc.authentik.clientSecret="$OIDC_CLIENT_SECRET" \
          --dry-run=client -o yaml | kubectl apply -f -

        # GitHub Deploy Key のリポジトリシークレット
        echo "Applying GitHub Deploy Key..."
        kubectl -n ${argocdCfg.namespace} create secret generic repo-k8s-apps \
          --from-file=sshPrivateKey=${deployKeyPath} \
          --from-literal=type=git \
          --from-literal=url=git@github.com:shinbunbun/k8s-apps.git \
          --dry-run=client -o yaml | kubectl apply -f -
        kubectl -n ${argocdCfg.namespace} label secret repo-k8s-apps \
          argocd.argoproj.io/secret-type=repository --overwrite

        # ArgoCD Server を再起動して OIDC 設定を反映
        echo "Restarting ArgoCD server to apply OIDC config..."
        kubectl -n ${argocdCfg.namespace} rollout restart deploy argocd-server

        echo "ArgoCD secrets setup completed."
      '';
  };
}

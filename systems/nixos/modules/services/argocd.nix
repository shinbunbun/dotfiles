/*
  ArgoCD GitOps デプロイメント設定モジュール

  このモジュールはk3sクラスタ上にArgoCDをデプロイします：
  - k3s HelmChart CRDを使用したArgoCD Helm chartの自動デプロイ
  - Traefik IngressRouteによるHTTPルーティング
  - SOPS統合によるOIDCクレデンシャルの安全な管理
  - GitHub Deploy Keyの自動投入（k8s-appsリポジトリアクセス用）
  - ArgoCD Image Updater用ghcr.ioレジストリ認証シークレットの投入
  - KSOPS（Kustomize + SOPS）によるGitリポジトリ内暗号化Secret管理
  - Authentik OIDCによるSSO認証
  - グループベースのRBAC（ArgoCD Admins / ArgoCD Users / mcp）
  - LAN 内 LoadBalancer Service（Cilium LB IPAM、固定 VIP）
  - MCP for ArgoCD 用ローカル apiKey アカウント（mcp）

  KSOPS対応:
  - repo-serverにKSOPSプラグインをinitContainerでインストール
  - k8s専用Age秘密鍵をKubernetes Secretとして投入し、repo-serverにマウント
  - k8s-appsリポジトリ内のSOPS暗号化SecretをArgoCD同期時に自動復号

  使用方法:
  1. dotfiles-privateのnixos-desktop設定でこのモジュールをimport
  2. secrets/argocd.yamlにOIDCクレデンシャル、Deploy Key、ghcr PATを設定
  3. secrets/k8s-age-key.yamlにk8s専用Age秘密鍵をSOPS暗号化して保存
  4. nixos-rebuildでデプロイ
  5. https://argocd.shinbunbun.com でアクセス

  前提条件:
  - k3sサービスが有効であること
  - Cloudflare Tunnelが設定済みであること
  - Authentik OIDCプロバイダーが設定済みであること
  - k8s専用Age鍵ペアが生成済みであること
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
      # Prometheus メトリクス Service (argocd-server-metrics :8083) を有効化
      # VictoriaMetrics VMAgent が VMServiceScrape 経由で収集する
      metrics.enabled = true;

      # LAN 内 LoadBalancer Service（Cilium LB IPAM、固定 VIP）
      # 用途: MCP for ArgoCD など、Cloudflare Tunnel + Authentik OIDC を経由せず
      # Bearer token のみで API を直叩きしたいクライアント向け。
      # 外部 (Cloudflare Tunnel) 経路は従来通り argocd-server ClusterIP を使う。
      service = {
        type = "LoadBalancer";
        annotations = {
          "io.cilium/lb-ipam-ips" = argocdCfg.lanLoadBalancerIp;
        };
      };
    };

    # Application Controller のメトリクス Service (argocd-metrics :8082) を有効化
    controller = {
      metrics.enabled = true;
    };

    # ApplicationSet Controller のメトリクス (Service のメトリクス port 8080) を有効化
    applicationSet = {
      metrics.enabled = true;
    };

    # ArgoCD Config (argocd-cm ConfigMap)
    configs = {
      cm = {
        url = "https://${argocdCfg.domain}";
        # KSOPS（Kustomize + SOPS）プラグインを有効化
        "kustomize.buildOptions" = "--enable-alpha-plugins --enable-exec";
        # Web Terminal（exec）機能を有効化
        "exec.enabled" = "true";
        # 利用可能なシェルの優先順位（Linux Podのみ想定）
        "exec.shells" = "bash,sh";
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

        # ローカル apiKey アカウント: MCP for ArgoCD (Claude Code) 用
        # OIDC を介さず、長寿命 Bearer token で API を叩くためのサービスアカウント。
        # トークン発行は `argocd account generate-token --account mcp` で 1 回行い、
        # dotfiles-private の SOPS (secrets/argocd.yaml) に保管する想定。
        # 権限は下の policy.csv の role:mcp で applications/projects の get/sync/action/
        # create/update に限定（delete は意図的に付与しない）。
        "accounts.mcp" = "apiKey";
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
          p, role:app-manager, exec, create, */*, allow
          p, role:app-manager, projects, get, *, allow

          p, role:mcp, applications, get, */*, allow
          p, role:mcp, applications, sync, */*, allow
          p, role:mcp, applications, action/*, */*, allow
          p, role:mcp, applications, create, */*, allow
          p, role:mcp, applications, update, */*, allow
          p, role:mcp, projects, get, *, allow
          p, role:mcp, repositories, get, *, allow
          p, role:mcp, clusters, get, *, allow
          p, role:mcp, logs, get, */*, allow

          g, ArgoCD Admins, role:admin
          g, ArgoCD Users, role:app-manager
          g, mcp, role:mcp
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

    # repo-server に KSOPS プラグインと Age 鍵を追加
    repoServer = {
      # repo-server のメトリクス (Service のメトリクス port 8084) を有効化
      metrics.enabled = true;

      # BestEffort QoS 脱却（Burstable へ）+ probe タイムアウト緩和
      # 値は shared/sections/services.nix の argocd.repoServer に集約
      resources = argocdCfg.repoServer.resources;
      livenessProbe = {
        timeoutSeconds = argocdCfg.repoServer.livenessProbeTimeoutSeconds;
      };
      readinessProbe = {
        timeoutSeconds = argocdCfg.repoServer.readinessProbeTimeoutSeconds;
      };

      # KSOPS バイナリをインストールする init container
      initContainers = [
        {
          name = "install-ksops";
          image = argocdCfg.ksopsImage;
          command = [
            "/bin/sh"
            "-c"
          ];
          args = [ "cp /usr/local/bin/ksops /custom-tools/ksops" ];
          volumeMounts = [
            {
              mountPath = "/custom-tools";
              name = "custom-tools";
            }
          ];
        }
      ];

      # カスタムツールと Age 鍵用のボリューム
      volumes = [
        {
          name = "custom-tools";
          emptyDir = { };
        }
        {
          name = "sops-age";
          secret = {
            secretName = "sops-age-key";
          };
        }
      ];

      # KSOPS バイナリと Age 鍵のマウント
      volumeMounts = [
        {
          mountPath = "/usr/local/bin/ksops";
          name = "custom-tools";
          subPath = "ksops";
        }
        {
          mountPath = "/home/argocd/.config/sops/age";
          name = "sops-age";
        }
      ];

      # SOPS が Age 鍵ファイルを見つけるための環境変数
      env = [
        {
          name = "XDG_CONFIG_HOME";
          value = "/home/argocd/.config";
        }
        {
          name = "SOPS_AGE_KEY_FILE";
          value = "/home/argocd/.config/sops/age/keys.txt";
        }
      ];
    };
  };

  # Nix store に保存するマニフェストファイル
  helmChartFile = pkgs.writeText "argocd-helmchart.yaml" helmChartManifest;

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

in
{

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
    "argocd/ghcr_pat" = {
      sopsFile = "${inputs.self}/secrets/argocd.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    # MCP for ArgoCD 用ローカル apiKey アカウント (mcp) の長寿命 Bearer token。
    # 発行は適用後に手動で `argocd account generate-token --account mcp` を実行し、
    # 出力文字列を dotfiles-private の secrets/argocd.yaml に SOPS 暗号化で保存する。
    # 下の systemd.services.argocd-secrets が argocd namespace に
    # Secret `argocd-mcp-token` (data.token) として投入する。
    "argocd/mcp_api_token" = {
      sopsFile = "${inputs.self}/secrets/argocd.yaml";
      owner = "root";
      group = "root";
      mode = "0400";
    };
    # k8s専用Age秘密鍵（KSOPS復号用、ArgoCD repo-serverに投入）
    "k8s/age_key" = {
      sopsFile = "${inputs.self}/secrets/k8s-age-key.yaml";
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
        ghcrPatPath = config.sops.secrets."argocd/ghcr_pat".path;
        mcpApiTokenPath = config.sops.secrets."argocd/mcp_api_token".path;
        k8sAgeKeyPath = config.sops.secrets."k8s/age_key".path;
        ghcrUsername = cfg.ghcr.username;
      in
      ''
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

        # k3s API サーバーが起動するまで待機
        echo "Waiting for k3s API server..."
        until kubectl cluster-info >/dev/null 2>&1; do
          sleep 5
        done

        # HelmChart CRD を kubectl apply で適用
        echo "Applying ArgoCD HelmChart manifest..."
        kubectl apply -f ${helmChartFile}

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

        # k8s専用 Age 秘密鍵を Kubernetes Secret として投入（KSOPS復号用）
        echo "Applying k8s Age key for KSOPS..."
        kubectl -n ${argocdCfg.namespace} create secret generic sops-age-key \
          --from-file=keys.txt=${k8sAgeKeyPath} \
          --dry-run=client -o yaml | kubectl apply -f -

        # Image Updater 用 ghcr.io レジストリ認証シークレット
        echo "Applying Image Updater ghcr.io credentials..."
        GHCR_PAT=$(cat ${ghcrPatPath})
        kubectl -n ${argocdCfg.namespace} create secret generic argocd-image-updater-ghcr-credentials \
          --from-literal=credentials="${ghcrUsername}:$GHCR_PAT" \
          --dry-run=client -o yaml | kubectl apply -f -

        # MCP for ArgoCD クライアント (Claude Code) が読み取る Bearer token Secret。
        # zsh init (home/modules/development/ai-tools.nix) が
        # `kubectl get secret argocd-mcp-token -n argocd -o jsonpath='{.data.token}'`
        # で取得して ARGOCD_API_TOKEN にエクスポートする。
        echo "Applying MCP API token..."
        kubectl -n ${argocdCfg.namespace} create secret generic argocd-mcp-token \
          --from-file=token=${mcpApiTokenPath} \
          --dry-run=client -o yaml | kubectl apply -f -

        # ArgoCD Server を再起動して OIDC 設定を反映
        echo "Restarting ArgoCD server to apply OIDC config..."
        kubectl -n ${argocdCfg.namespace} rollout restart deploy argocd-server

        echo "ArgoCD secrets setup completed."
      '';
  };
}

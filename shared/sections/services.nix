/*
  サービス設定セクション

  ArgoCD、GitHub Container Registry、
  Authentik、RouterOSバックアップの設定を定義します。
*/
v: {
  argocd = {
    domain = v.assertString "argocd.domain" "argocd.shinbunbun.com";
    namespace = v.assertString "argocd.namespace" "argocd";
    helmChartVersion = v.assertString "argocd.helmChartVersion" "9.4.3";
    # KSOPS（Kustomize + SOPS）プラグインのイメージバージョン
    ksopsImage = v.assertString "argocd.ksopsImage" "viaductoss/ksops:v4.3.2";
    # k8s専用Age公開鍵（Secret暗号化用、秘密鍵はArgoCD repo-serverのみ保持）
    k8sAgePublicKey = v.assertString "argocd.k8sAgePublicKey" "age1jfkfpwsze8rj0pnzmachzwpqaqk594s7qkazucavues4g499waeqwdkac4";
    # LAN 内 LoadBalancer Service の固定 VIP（Cilium LB IPAM、192.168.128.0/24 プールから割当）
    # MCP for ArgoCD など、Cloudflare Tunnel/Authentik OIDC を経由せず Bearer token のみで
    # API 直叩きしたいクライアント向け。`io.cilium/lb-ipam-ips` annotation で固定する。
    lanLoadBalancerIp = v.assertString "argocd.lanLoadBalancerIp" "192.168.128.21";

    # repo-server のリソース要求/上限と probe タイムアウト
    # BestEffort QoS だとノード逼迫時にスケジューリング優先度が最低となり、
    # gRPC ヘルスチェック goroutine の wakeup が probe timeoutSeconds を超えて
    # "Error serving health check request / context canceled" が散発する。
    # CPU は throttling を避けるため limit を設けず requests のみ指定する。
    repoServer = {
      resources = {
        requests = {
          cpu = v.assertString "argocd.repoServer.resources.requests.cpu" "100m";
          memory = v.assertString "argocd.repoServer.resources.requests.memory" "256Mi";
        };
        limits = {
          memory = v.assertString "argocd.repoServer.resources.limits.memory" "512Mi";
        };
      };
      # kubelet probe のタイムアウト秒数（argo-cd Helm chart のデフォルトは
      # 短く、git fetch 等で一時的に goroutine が遅延すると簡単に超過するため緩和）
      livenessProbeTimeoutSeconds = v.assertPositiveInt "argocd.repoServer.livenessProbeTimeoutSeconds" 10;
      readinessProbeTimeoutSeconds = v.assertPositiveInt "argocd.repoServer.readinessProbeTimeoutSeconds" 10;
    };
  };

  ghcr = {
    registry = v.assertString "ghcr.registry" "ghcr.io";
    username = v.assertString "ghcr.username" "shinbunbun";
  };

  authentik = {
    domain = v.assertString "authentik.domain" "auth.shinbunbun.com";
    baseUrl = v.assertString "authentik.baseUrl" "https://auth.shinbunbun.com";
  };

  mlxLm = {
    model = v.assertString "mlxLm.model" "mlx-community/Qwen3.5-4B-MLX-4bit";
    port = v.assertPort "mlxLm.port" 8081;
  };

  # llama.cpp ベースのローカル LLM 推論サーバ (services/llama-cpp.nix を参照)。
  # Qwen3.6-35B-A3B のような MoE モデルを CPU オフロード推論する想定で、
  # ホスト側 (dotfiles-private) で modelPath と enable を指定する。
  llamaCpp = {
    modelAlias = v.assertString "llamaCpp.modelAlias" "qwen3.6-35b-a3b";
    port = v.assertPort "llamaCpp.port" 8082;
    threads = v.assertPositiveInt "llamaCpp.threads" 8;
    threadsBatch = v.assertPositiveInt "llamaCpp.threadsBatch" 16;
    contextSize = v.assertPositiveInt "llamaCpp.contextSize" 32768;
    parallelSlots = v.assertPositiveInt "llamaCpp.parallelSlots" 1;
    # MoE expert FFN を CPU 強制する層数 (0 で無効化、Qwen3.6-35B-A3B は 40 層)
    nCpuMoe = v.assertNonNegativeInt "llamaCpp.nCpuMoe" 40;
    host = v.assertString "llamaCpp.host" "0.0.0.0";
  };

  jellyfin = {
    enable = v.assertBool "jellyfin.enable" false;
    port = v.assertPort "jellyfin.port" 8096;
  };

  nextcloud = {
    enable = v.assertBool "nextcloud.enable" false;
    port = v.assertPort "nextcloud.port" 8443;
    domain = v.assertString "nextcloud.domain" "nextcloud.shinbunbun.com";
  };

  immich = {
    enable = v.assertBool "immich.enable" false;
    port = v.assertPort "immich.port" 2283;
    domain = v.assertString "immich.domain" "immich.shinbunbun.com";
  };
}

/*
  サービス設定セクション

  CouchDB、ArgoCD、GitHub Container Registry、
  Authentik、RouterOSバックアップの設定を定義します。
*/
v: {
  couchdb = {
    containerName = v.assertString "couchdb.containerName" "couchdb-obsidian";
    port = v.assertPort "couchdb.port" 5984;
    configPath = v.assertPath "couchdb.configPath" "/opt/couchdb/etc/local.d/10-jwt.ini";
    jwt = {
      rolesClaimPath = v.assertString "couchdb.jwt.rolesClaimPath" "groups";
      allowedAlgorithms = v.assertString "couchdb.jwt.allowedAlgorithms" "ES256";
    };
  };

  argocd = {
    domain = v.assertString "argocd.domain" "argocd.shinbunbun.com";
    namespace = v.assertString "argocd.namespace" "argocd";
    helmChartVersion = v.assertString "argocd.helmChartVersion" "9.4.3";
    # KSOPS（Kustomize + SOPS）プラグインのイメージバージョン
    ksopsImage = v.assertString "argocd.ksopsImage" "viaductoss/ksops:v4.3.2";
    # k8s専用Age公開鍵（Secret暗号化用、秘密鍵はArgoCD repo-serverのみ保持）
    k8sAgePublicKey = v.assertString "argocd.k8sAgePublicKey" "age1jfkfpwsze8rj0pnzmachzwpqaqk594s7qkazucavues4g499waeqwdkac4";
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
  };

  routerosBackup = {
    routerIP = v.assertIP "routerosBackup.routerIP" "192.168.1.1";
    routerUser = v.assertString "routerosBackup.routerUser" "admin";
    sshKeyPath = v.assertPath "routerosBackup.sshKeyPath" "/home/bunbun/.ssh/id_ed25519";
    backupDir = v.assertPath "routerosBackup.backupDir" "/var/lib/routeros-backup";
    git = {
      userName = v.assertString "routerosBackup.git.userName" "RouterOS Backup Service";
      userEmail = v.assertEmail "routerosBackup.git.userEmail" "routeros-backup@localhost";
    };
    # リトライ設定
    maxRetries = v.assertPositiveInt "routerosBackup.maxRetries" 3;
    retryDelay = v.assertPositiveInt "routerosBackup.retryDelay" 30;
  };
}

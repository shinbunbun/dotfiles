# cells/core/config.nix
# 共通設定値を管理するファイル
{
  # ネットワーク設定
  networking = {
    # ホスト情報
    hosts = {
      nixos = {
        hostname = "nixos";
        domain = "shinbunbun.com";
      };
      nixosDesktop = {
        ip = "192.168.1.4";
        hostname = "nixos-desktop";
      };
    };
    
    # インターフェース設定
    interfaces = {
      primary = "eno1";
      wireless = "wlp1s0";
    };
    
    # ファイアウォール設定
    firewall = {
      generalPort = 8888;
      kubernetesApiPort = 6443;
      nfsPort = 2049;
    };
  };
  
  # SSH設定
  ssh = {
    port = 31415;
    authorizedKeysPath = "/etc/ssh/authorized_keys.d/%u";
  };
  
  # Fail2ban設定
  fail2ban = {
    ignoreNetworks = [
      "192.168.11.0/24"
      "163.143.0.0/16"
    ];
  };
  
  # Kubernetes設定
  kubernetes = {
    master = {
      ip = "192.168.1.3";
      hostname = "api.kube";
    };
  };
  
  # NFS設定
  nfs = {
    exportPath = "/export/k8s";
    clients = [
      { ip = "192.168.1.3"; }
      { ip = "192.168.1.4"; }
    ];
    options = "rw,nohide,insecure,no_subtree_check,no_root_squash";
  };
}
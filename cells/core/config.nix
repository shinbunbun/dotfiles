# cells/core/config.nix
# 共通設定値を管理するファイル
{
  # ユーザー設定
  users = {
    nixos = {
      username = "bunbun";
      homeDirectory = "/home/bunbun";
    };
    darwin = {
      username = "shinbunbun";
      homeDirectory = "/Users/shinbunbun";
    };
  };

  # Git設定
  git = {
    userName = "shinbunbun";
    userEmail = "34409044+shinbunbun@users.noreply.github.com";
    coreEditor = "code --wait";
  };

  # システムバージョン設定
  system = {
    nixosStateVersion = "21.11";
    homeStateVersion = "24.11";
    timeZone = "Asia/Tokyo";
  };

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

  # SOPS設定
  sops = {
    keyFile = "/var/lib/sops-nix/key.txt";
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

  # WireGuard設定
  wireguard = {
    # 共通設定
    network = {
      subnet = "10.100.0.0/24";
      serverIp = "10.100.0.1";
    };

    # NixOS用設定
    nixos = {
      interfaceName = "wg0";
      clientIp = "10.100.0.4";
      serverEndpoint = "192.168.1.1:13231";
      privateKeyPath = "wireguard/home/nixosClientPrivKey";
      publicKeyPath = "wireguard/home/publicKey";
    };

    # Darwin(macOS)用設定
    darwin = {
      interfaceName = "wg-home";
      clientIp = "10.100.0.2";
      privateKeyPath = "wireguard/home/macClientPrivKey";
      publicKeyPath = "wireguard/home/publicKey";
      endpointPath = "wireguard/home/endpoint";
      allowedNetworks = [
        "192.168.1.0/24"
        "10.100.0.0/24"
      ];
    };

    # 共通のkeepalive設定
    persistentKeepalive = 25;
  };

  # RouterOSバックアップ設定
  routerosBackup = {
    routerIP = "192.168.1.1";
    routerUser = "admin";
    sshKeyPath = "/home/bunbun/.ssh/id_ed25519";
    backupDir = "/var/lib/routeros-backup";
    git = {
      userName = "RouterOS Backup Service";
      userEmail = "routeros-backup@localhost";
    };
  };
}

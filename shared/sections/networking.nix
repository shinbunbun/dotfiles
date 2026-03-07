/*
  ネットワーク・SSH・Fail2ban・SOPS設定セクション

  ホスト情報、インターフェース、ファイアウォール、SSH、
  Fail2ban、SOPS秘密鍵パスを定義します。
*/
v: {
  networking = {
    hosts = {
      nixos = {
        hostname = v.assertString "networking.hosts.nixos.hostname" "nixos";
        domain = v.assertString "networking.hosts.nixos.domain" "shinbunbun.com";
      };
      nixosDesktop = {
        ip = v.assertIP "networking.hosts.nixosDesktop.ip" "192.168.1.4";
        hostname = v.assertString "networking.hosts.nixosDesktop.hostname" "nixos-desktop";
      };
      macmini = {
        ip = v.assertIP "networking.hosts.macmini.ip" "192.168.1.5";
        hostname = v.assertString "networking.hosts.macmini.hostname" "shinbunbun-macmini";
      };
    };

    interfaces = {
      primary = v.assertString "networking.interfaces.primary" "eno1";
      wireless = v.assertString "networking.interfaces.wireless" "wlp1s0";
    };

    allowedNetworks = [
      "192.168.1.0/24" # ローカルネットワーク1
      "192.168.11.0/24" # ローカルネットワーク2
      "10.100.0.0/24" # WireGuardネットワーク
    ];

    firewall = {
      generalPort = v.assertPort "networking.firewall.generalPort" 8888;
      nfsPort = v.assertPort "networking.firewall.nfsPort" 2049;
    };
  };

  ssh = {
    port = v.assertPort "ssh.port" 31415;
    authorizedKeysPath = v.assertString "ssh.authorizedKeysPath" "/etc/ssh/authorized_keys.d/%u";
  };

  fail2ban = {
    ignoreNetworks = v.assertListOf "fail2ban.ignoreNetworks" [
      "192.168.11.0/24"
      "163.143.0.0/16"
    ] v.assertCIDR;
  };

  sops = {
    keyFile = v.assertPath "sops.keyFile" "/var/lib/sops-nix/key.txt";
  };
}

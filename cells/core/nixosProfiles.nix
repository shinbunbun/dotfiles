# cells/core/nixosProfiles.nix
{ inputs, cell }:
let
  kubeMasterIP = "192.168.1.3";
  kubeMasterHostname = "api.kube";
in
{
  default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      system.stateVersion = "21.11";
      system.autoUpgrade.enable = false;
      system.autoUpgrade.allowReboot = false;
      nix.extraOptions = ''
        experimental-features = nix-command flakes
      '';
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      networking.hostName = "nixos";
      networking.useDHCP = false;
      networking.interfaces.eno1.useDHCP = true;
      networking.interfaces.wlp1s0.useDHCP = false;
      networking.enableIPv6 = true;
      networking.firewall.allowedTCPPorts = [
        6443
        8888
        2049
      ];
      networking.extraHosts = ''
        ${kubeMasterIP} ${kubeMasterHostname}
        192.168.1.4 nixos-desktop
      '';
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        reflector = false;
        wideArea = true;
        publish = {
          enable = true;
          addresses = false;
          workstation = true;
        };
        # extraConfig = ''
        #   [server]
        #   allow-interfaces=eth0,wg0
        # '';
      };
      environment.etc."avahi/hosts".text = ''
        192.168.1.3  nixos.local
        10.100.0.4 nixos.local
      '';
      networking.firewall.allowedUDPPorts = [ 5353 ];
      time.timeZone = "Asia/Tokyo";
      services.openssh = {
        enable = true;
        ports = [ 31415 ];
        settings = {
          X11Forwarding = true;
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
        extraConfig = ''
          AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
        '';
      };
      services.fail2ban = {
        enable = true;
        ignoreIP = [
          "192.168.11.0/24"
          "163.143.0.0/16"
        ];
      };
      security.pam.services = {
        sudo.sshAgentAuth = true;
      };
      virtualisation.docker.enable = true;
      services.nfs.server.enable = true;
      services.nfs.server.exports = ''
        /export/k8s  192.168.1.4(rw,nohide,insecure,no_subtree_check,no_root_squash)
        /export/k8s  192.168.1.3(rw,nohide,insecure,no_subtree_check,no_root_squash)
      '';
      users.users.bunbun = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "docker"
        ];
        shell = pkgs.zsh;
        # authorizedKeys.keyFilesはprofileごとに上書き
      };
      programs.zsh.enable = true;
      environment.systemPackages = with pkgs; [
        vim
        wget
        kompose
        kubectl
        kubernetes
        polkit
        wireguard-tools
      ];

      virtualisation = {
        vmVariantWithBootLoader = {
          virtualisation = {
            memorySize = 2048;
            cores = 2;
            graphics = false;
            useEFIBoot = true;
          };
        };
      };

      sops = {
        defaultSopsFile = "${inputs.self}/secrets/ssh-keys.yaml";
        age.keyFile = "/var/lib/sops-nix/key.txt";

        secrets."ssh_keys/bunbun" = {
          # 復号後に **この場所** へシンボリックリンク
          path = "/etc/ssh/authorized_keys.d/bunbun";

          owner = "bunbun"; # 公開鍵なので bunbun:wheel でも問題なし
          group = "wheel";
          mode = "0444";

          # ユーザー作成前に用意してほしい場合
          neededForUsers = true;
        };

        # WireGuard設定の追加
        secrets."wireguard/home/nixosClientPrivKey" = {
          sopsFile = "${inputs.self}/secrets/wireguard.yaml";
        };

        secrets."wireguard/home/publicKey" = {
          sopsFile = "${inputs.self}/secrets/wireguard.yaml";
        };

        # WireGuard設定ファイル全体を生成
        templates."wireguard/wg0.conf" = {
          content = ''
            [Interface]
            PrivateKey = ${config.sops.placeholder."wireguard/home/nixosClientPrivKey"}
            Address = 10.100.0.4/24

            [Peer]
            PublicKey = ${config.sops.placeholder."wireguard/home/publicKey"}
            Endpoint = 192.168.1.1:13231
            PersistentKeepalive = 25
            AllowedIPs = 10.100.0.1/32
          '';
          path = "/etc/wireguard/wg0.conf";
          owner = "root";
          group = "root";
          mode = "0600";
        };
      };

      # ── 2-1  WireGuard インターフェース ────────────────
      networking.wg-quick.interfaces.wg0 = {
        # sopsで生成された設定ファイルを直接使用
        configFile = "/etc/wireguard/wg0.conf";
      };

      security.polkit.enable = true;
    };
  optimise = {
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  vm =
    {
      lib,
      ...
    }:
    {
      boot.initrd.availableKernelModules = lib.mkDefault [
        "virtio_pci"
        "virtio_blk"
      ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos-root";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/nixos-boot";
        fsType = "vfat";
      };
    };
}

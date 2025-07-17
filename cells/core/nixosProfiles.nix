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
        publish = {
          enable = true;
          addresses = true;
          workstation = true;
        };
      };
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

        secrets."couchdb/admin_password" = {
          owner = "root";
          group = "wheel";
          mode = "0400";
        };

        secrets."couchdb/database_name" = {
          owner = "root";
          group = "wheel";
          mode = "0400";
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

        templates."couchdb/local.ini" = {
          content = ''
            [couchdb]
            single_node=true

            [chttpd]
            enable_cors = true
            bind_address = 0.0.0.0
            port = 5984

            [cors]
            origins = app://obsidian.md,capacitor://localhost,http://localhost,https://obsidian.${
              config.networking.domain or "local"
            }
            credentials = true
            headers = accept, authorization, content-type, origin, referer, x-couch-request-id
            methods = GET, PUT, POST, HEAD, DELETE, OPTIONS

            [couch_httpd_auth]
            require_valid_user = true

            [admins]
            admin = ${config.sops.placeholder."couchdb/admin_password"}
          '';
          path = "/var/lib/couchdb/local.ini";
          owner = "root";
          group = "docker";
          mode = "0640";
        };
      };

      # ── 2-1  WireGuard インターフェース ────────────────
      networking.wg-quick.interfaces.wg0 = {
        # sopsで生成された設定ファイルを直接使用
        configFile = "/etc/wireguard/wg0.conf";
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/couchdb 0755 root docker -"
        "d /var/lib/couchdb/data 0755 999 999 -"
      ];

      # CouchDBコンテナサービス
      systemd.services.couchdb-obsidian = {
        description = "CouchDB for Obsidian LiveSync";
        after = [
          "docker.service"
          "sops-nix.service"
        ];
        requires = [ "docker.service" ];
        wants = [ "sops-nix.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "notify";
          Restart = "always";
          RestartSec = "10s";
          TimeoutStartSec = "300s";

          ExecStartPre = [
            # 既存コンテナの停止・削除
            "-${pkgs.docker}/bin/docker stop couchdb-obsidian"
            "-${pkgs.docker}/bin/docker rm couchdb-obsidian"
            # 最新イメージの取得
            "${pkgs.docker}/bin/docker pull couchdb:3.3.3"
          ];

          ExecStart = ''
            ${pkgs.docker}/bin/docker run --name couchdb-obsidian \
              --restart unless-stopped \
              -p 127.0.0.1:5984:5984 \
              -e COUCHDB_USER=admin \
              -e COUCHDB_PASSWORD_FILE=/run/secrets/couchdb_password \
              -v /var/lib/couchdb/data:/opt/couchdb/data \
              -v /var/lib/couchdb/local.ini:/opt/couchdb/etc/local.ini:ro \
              -v ${config.sops.secrets."couchdb/admin_password".path}:/run/secrets/couchdb_password:ro \
              couchdb:3.3.3
          '';

          ExecStop = "${pkgs.docker}/bin/docker stop couchdb-obsidian";
          ExecReload = "${pkgs.docker}/bin/docker restart couchdb-obsidian";
        };
      };

      # ヘルスチェック用サービス
      systemd.services.couchdb-health-check = {
        description = "CouchDB Health Check";
        after = [ "couchdb-obsidian.service" ];
        wants = [ "couchdb-obsidian.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeScript "couchdb-health-check" ''
            #!${pkgs.bash}/bin/bash
            set -e
            echo "Waiting for CouchDB to be ready..."
            for i in {1..30}; do
              if ${pkgs.curl}/bin/curl -f http://localhost:5984/ >/dev/null 2>&1; then
                echo "CouchDB is ready!"
                exit 0
              fi
              echo "Attempt $i/30: CouchDB not ready yet, waiting..."
              sleep 2
            done
            echo "CouchDB failed to start within timeout"
            exit 1
          '';
        };
      };

      systemd.timers.couchdb-health-check = {
        description = "CouchDB Health Check Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2m";
          OnUnitActiveSec = "5m";
          Persistent = true;
        };
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

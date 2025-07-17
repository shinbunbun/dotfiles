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
      networking.domain = "shinbunbun.com";
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

        secrets."couchdb_admin_password" = {
          key = "couchdb/admin_password";
          sopsFile = "${inputs.self}/secrets/couchdb.yaml";
          owner = "root";
          group = "root";
          mode = "0400";
        };

        secrets."couchdb_database_name" = {
          key = "couchdb/database_name";
          sopsFile = "${inputs.self}/secrets/couchdb.yaml";
          owner = "root";
          group = "root";
          mode = "0400";
        };

        secrets."cloudflare_tunnel_token" = {
          key = "cloudflare/tunnel_token";
          sopsFile = "${inputs.self}/secrets/couchdb.yaml";
          owner = "root";
          group = "root";
          mode = "0400";
        };

        secrets."cloudflare_account_tag" = {
          key = "cloudflare/account_tag";
          sopsFile = "${inputs.self}/secrets/couchdb.yaml";
          owner = "root";
          group = "root";
          mode = "0400";
        };

        secrets."cloudflare_tunnel_secret" = {
          key = "cloudflare/tunnel_secret";
          sopsFile = "${inputs.self}/secrets/couchdb.yaml";
          owner = "root";
          group = "root";
          mode = "0400";
        };

        secrets."cloudflare_tunnel_id" = {
          key = "cloudflare/tunnel_id";
          sopsFile = "${inputs.self}/secrets/couchdb.yaml";
          owner = "root";
          group = "root";
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

        # CouchDB environment file template
        templates."couchdb/env" = {
          content = ''
            COUCHDB_USER=admin
            COUCHDB_PASSWORD=${config.sops.placeholder."couchdb_admin_password"}
          '';
          path = "/run/secrets/rendered/couchdb/env";
          owner = "root";
          group = "root";
          mode = "0640";
        };

        # Cloudflare credentials file template
        templates."cloudflare/credentials.json" = {
          content = ''
            {
              "AccountTag": "${config.sops.placeholder."cloudflare_account_tag"}",
              "TunnelSecret": "${config.sops.placeholder."cloudflare_tunnel_secret"}",
              "TunnelID": "${config.sops.placeholder."cloudflare_tunnel_id"}"
            }
          '';
          path = "/run/secrets/rendered/cloudflare/credentials.json";
          owner = "root";
          group = "root";
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

      # CouchDB OCI Container
      virtualisation.oci-containers = {
        backend = "docker";
        containers = {
          couchdb-obsidian = {
            image = "couchdb:3.3.3";
            autoStart = true;
            ports = [ "127.0.0.1:5984:5984" ];
            volumes = [
              "/var/lib/couchdb/data:/opt/couchdb/data"
            ];
            environmentFiles = [
              config.sops.templates."couchdb/env".path
            ];
            extraOptions = [
              "--health-cmd=curl -f http://localhost:5984/ || exit 1"
              "--health-interval=30s"
              "--health-timeout=10s"
              "--health-retries=3"
            ];
          };
        };
      };

      # CouchDB データベース初期化サービス
      systemd.services.couchdb-init = {
        description = "Initialize CouchDB databases";
        after = [ "docker-couchdb-obsidian.service" ];
        wants = [ "docker-couchdb-obsidian.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeScript "couchdb-init" ''
            #!${pkgs.bash}/bin/bash
            set -e

            echo "Waiting for CouchDB to be ready..."
            for i in {1..30}; do
              if ${pkgs.curl}/bin/curl -f http://localhost:5984/ >/dev/null 2>&1; then
                echo "CouchDB is ready!"
                break
              fi
              echo "Attempt $i/30: CouchDB not ready yet, waiting..."
              sleep 2
            done

            # Read password from sops secret
            PASSWORD=$(cat ${config.sops.secrets."couchdb_admin_password".path})

            # Create obsidian-livesync database
            echo "Creating obsidian-livesync database..."
            ${pkgs.curl}/bin/curl -f -u admin:$PASSWORD \
              -X PUT http://localhost:5984/obsidian-livesync 2>/dev/null || {
              echo "Database obsidian-livesync already exists or creation failed"
            }

            # Create database for the configured database name
            DATABASE_NAME=$(cat ${config.sops.secrets."couchdb_database_name".path})
            echo "Creating $DATABASE_NAME database..."
            ${pkgs.curl}/bin/curl -f -u admin:$PASSWORD \
              -X PUT http://localhost:5984/$DATABASE_NAME 2>/dev/null || {
              echo "Database $DATABASE_NAME already exists or creation failed"
            }

            # Configure CORS settings via CouchDB API
            echo "Configuring CORS settings..."
            ${pkgs.curl}/bin/curl -f -u admin:$PASSWORD \
              -X PUT http://localhost:5984/_node/nonode@nohost/_config/httpd/enable_cors \
              -H "Content-Type: application/json" \
              -d '"true"' 2>/dev/null || echo "CORS enable setting failed"

            ${pkgs.curl}/bin/curl -f -u admin:$PASSWORD \
              -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/origins \
              -H "Content-Type: application/json" \
              -d '"app://obsidian.md,capacitor://localhost,http://localhost,https://private-obsidian.${config.networking.domain}"' 2>/dev/null || echo "CORS origins setting failed"

            ${pkgs.curl}/bin/curl -f -u admin:$PASSWORD \
              -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/credentials \
              -H "Content-Type: application/json" \
              -d '"true"' 2>/dev/null || echo "CORS credentials setting failed"

            ${pkgs.curl}/bin/curl -f -u admin:$PASSWORD \
              -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/methods \
              -H "Content-Type: application/json" \
              -d '"GET,PUT,POST,HEAD,DELETE,OPTIONS"' 2>/dev/null || echo "CORS methods setting failed"

            ${pkgs.curl}/bin/curl -f -u admin:$PASSWORD \
              -X PUT http://localhost:5984/_node/nonode@nohost/_config/cors/headers \
              -H "Content-Type: application/json" \
              -d '"accept,authorization,content-type,origin,referer,x-couch-request-id,x-requested-with"' 2>/dev/null || echo "CORS headers setting failed"

            echo "CouchDB initialization completed successfully!"
          '';
        };
      };

      security.polkit.enable = true;

      # Cloudflare Tunnel for Obsidian LiveSync
      services.cloudflared = {
        enable = true;
        tunnels = {
          "obsidian-livesync" = {
            default = "http_status:404";
            credentialsFile = config.sops.templates."cloudflare/credentials.json".path;
            ingress = {
              # CouchDB for Obsidian LiveSync
              "private-obsidian.${config.networking.domain}" = {
                service = "http://localhost:5984";
                originRequest = {
                  noTLSVerify = true;
                };
              };
            };
          };
        };
      };
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

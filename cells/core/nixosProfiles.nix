# cells/core/nixosProfiles.nix
{ inputs, cell }:
let
  kubeMasterIP = "192.168.1.3";
  kubeMasterHostname = "api.kube";
  isVM = builtins.getEnv "NIXOS_BUILD_VM" == "1";
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
      system.autoUpgrade.enable = true;
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
        # VMビルド時はauthorizedKeysFileを指定しない
        extraConfig = lib.mkIf (!isVM) ''
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
        # VMの場合はダミーの空のキーを設定
        openssh.authorizedKeys.keys = lib.mkIf (isVM) [ "" ];
      };
      programs.zsh.enable = true;
      environment.systemPackages = with pkgs; [
        vim
        wget
        kompose
        kubectl
        kubernetes
        polkit
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
      # users.users.bunbun.openssh.authorizedKeys.keyFiles = [
      #   config.sops.secrets."ssh_keys/bunbun".path
      # ];
      # system.activationScripts.copyBunbunAuthorizedKeys = {
      #   text = ''
      #     echo "認証鍵のコピーを開始します..."
      #     mkdir -p /etc/ssh/authorized_keys.d
      #     if [ -f "${config.sops.secrets."ssh_keys/bunbun".path}" ]; then
      #       echo "ソースファイルが存在します: ${config.sops.secrets."ssh_keys/bunbun".path}"
      #       cp "${config.sops.secrets."ssh_keys/bunbun".path}" /etc/ssh/authorized_keys.d/bunbun
      #       chmod 0444 /etc/ssh/authorized_keys.d/bunbun
      #       echo "認証鍵のコピーが完了しました"
      #       ls -la /etc/ssh/authorized_keys.d/bunbun
      #     else
      #       echo "エラー: ソースファイルが見つかりません: ${config.sops.secrets."ssh_keys/bunbun".path}"
      #     fi
      #   '';
      # };

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
  sops =
    { config, lib, ... }:
    {
      # VMモード時はSOPS関連の設定をスキップ
      config = lib.mkIf (!isVM) {
        sops = {
          defaultSopsFile = "${inputs.self}/secrets/ssh-keys.yaml";
          age.keyFile = "/var/lib/sops-nix/key.txt";
          secrets."ssh_keys/bunbun" = {
            owner = "bunbun";
            mode = "0440";
          };
        };
        users.users.bunbun.openssh.authorizedKeys.keyFiles = [
          config.sops.secrets."ssh_keys/bunbun".path
        ];
        # アクティベーションスクリプトでのコピー
        system.activationScripts.copyBunbunAuthorizedKeys = {
          text = ''
            echo "認証鍵のコピーを開始します..."
            mkdir -p /etc/ssh/authorized_keys.d
            if [ -f "${config.sops.secrets."ssh_keys/bunbun".path}" ]; then
              echo "ソースファイルが存在します: ${config.sops.secrets."ssh_keys/bunbun".path}"
              cp "${config.sops.secrets."ssh_keys/bunbun".path}" /etc/ssh/authorized_keys.d/bunbun
              chmod 0444 /etc/ssh/authorized_keys.d/bunbun
              echo "認証鍵のコピーが完了しました"
              ls -la /etc/ssh/authorized_keys.d/bunbun
            else
              echo "エラー: ソースファイルが見つかりません: ${config.sops.secrets."ssh_keys/bunbun".path}"
            fi
          '';
        };
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

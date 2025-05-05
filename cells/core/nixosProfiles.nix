{
  inputs,
  cell,
}:
{
  default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      kubeMasterIP = "192.168.1.3";
      kubeMasterHostname = "api.kube";
      isCI = builtins.getEnv "CI" == "true";
    in
    {
      # This value determines the NixOS release
      system.stateVersion = "21.11";

      # Auto upgrade
      system.autoUpgrade.enable = true;
      system.autoUpgrade.allowReboot = false;

      nix.extraOptions = ''
        experimental-features = nix-command flakes
      '';

      # Use the systemd-boot EFI boot loader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      networking.hostName = "nixos";
      networking.useDHCP = false;
      networking.interfaces.eno1.useDHCP = true;
      networking.interfaces.wlp1s0.useDHCP = false;
      networking.enableIPv6 = true;

      # Open ports in the firewall.
      networking.firewall.allowedTCPPorts = [
        6443
        8888
        2049
      ];

      networking.extraHosts = ''
        ${kubeMasterIP} ${kubeMasterHostname}
        192.168.1.4 nixos-desktop
      '';

      # Avahi config
      services.avahi = {
        enable = true;
        publish = {
          enable = true;
          addresses = true;
          workstation = true;
        };
      };

      # Set your time zone
      time.timeZone = "Asia/Tokyo";

      # Enable the OpenSSH daemon.
      services.openssh = {
        enable = true;
        ports = [ 31415 ];
        settings = {
          X11Forwarding = true;
          PermitRootLogin = "no";
          PasswordAuthentication = false;
        };
      };

      # fail2ban config
      services.fail2ban = {
        enable = true;
        ignoreIP = [
          "192.168.11.0/24"
          "163.143.0.0/16"
        ];
      };

      # PAM
      security.pam.services = {
        sudo.sshAgentAuth = true;
      };

      # add docker config
      virtualisation.docker.enable = true;

      # NFS server
      services.nfs.server.enable = true;
      services.nfs.server.exports = ''
        /export/k8s  192.168.1.4(rw,nohide,insecure,no_subtree_check,no_root_squash)
        /export/k8s  192.168.1.3(rw,nohide,insecure,no_subtree_check,no_root_squash)
      '';

      # sops-nixの有効化
      sops =
        if isCI then
          { }
        else
          {
            defaultSopsFile = ../secrets/ssh-keys.yaml;
            age.keyFile = "/var/lib/sops-nix/key.txt";
            secrets."ssh_keys/bunbun" = {
              owner = "bunbun";
            };
          };

      # Define a user account. Don't forget to set a password with 'passwd'.
      users.users.bunbun = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "docker"
        ]; # Enable 'sudo' for the user.
        openssh.authorizedKeys.keyFiles =
          if isCI then
            [ ]
          else
            (
              if
                config ? sops
                && config.sops.secrets ? "ssh_keys/bunbun"
                && config.sops.secrets."ssh_keys/bunbun" ? path
              then
                [ config.sops.secrets."ssh_keys/bunbun".path ]
              else
                [ ]
            );
        shell = pkgs.zsh;
      };

      programs.zsh.enable = true;

      # List packages installed in system profile.
      environment.systemPackages = with pkgs; [
        vim
        wget
        kompose
        kubectl
        kubernetes
      ];
    };

  optimise = {
    # https://wiki.nixos.org/wiki/Storage_optimization
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}

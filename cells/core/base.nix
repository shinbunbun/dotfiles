# cells/core/base.nix
{
  config,
  pkgs,
  lib,
  ...
}:
let
  kubeMasterIP = "192.168.1.3";
  kubeMasterHostname = "api.kube";
in
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
  ];

  virtualisation.vmVariantWithBootLoader = {
    virtualisation = {
      memorySize = 2048;
      cores = 2;
      graphics = false;
    };
  };

  sops = {
    defaultSopsFile = ../secrets/ssh-keys.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets."ssh_keys/bunbun" = {
      owner = "bunbun";
    };
  };
  # users.users.bunbun.openssh.authorizedKeys.keyFiles = [
  #   config.sops.secrets."ssh_keys/bunbun".path
  # ];
  system.activationScripts.copyBunbunAuthorizedKeys = {
    text = ''
      mkdir -p /etc/ssh/authorized_keys.d
      cp ${config.sops.secrets."ssh_keys/bunbun".path} /etc/ssh/authorized_keys.d/bunbun
      chmod 0444 /etc/ssh/authorized_keys.d/bunbun
    '';
  };
}

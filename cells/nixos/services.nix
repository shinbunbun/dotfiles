{ config, pkgs, ... }:

{
  # Set your time zone
  time.timeZone = "Asia/Tokyo";

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    vim
    wget
    kompose
    kubectl
    kubernetes
  ];

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

  # Auto upgrade
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = false;

  # This value determines the NixOS release
  system.stateVersion = "21.11";
}

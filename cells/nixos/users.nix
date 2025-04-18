{ config, pkgs, ... }:

{
  # sops-nixの有効化
  sops.defaultSopsFile = ../secrets/ssh-keys.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # 秘密情報の定義
  sops.secrets."ssh_keys/bunbun" = {
    owner = "bunbun";
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.bunbun = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Enable 'sudo' for the user.
    openssh.authorizedKeys.keyFiles = [
      config.sops.secrets."ssh_keys/bunbun".path
    ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
} 

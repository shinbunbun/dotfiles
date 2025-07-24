# cells/core/nixosProfiles/security.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  sopsWireGuardHelper = import ../sops-wireguard.nix { inherit inputs cell; };
  cfg = import ../config.nix;
in
{
  # PAM設定
  security.pam.services = {
    sudo.sshAgentAuth = true;
  };

  # Polkit
  security.polkit.enable = true;

  # SOPS設定
  sops = {
    defaultSopsFile = "${inputs.self}/secrets/ssh-keys.yaml";
    age.keyFile = cfg.sops.keyFile;

    secrets."ssh_keys/bunbun" = {
      path = "/etc/ssh/authorized_keys.d/bunbun";
      owner = "bunbun";
      group = "wheel";
      mode = "0444";
      neededForUsers = true;
    };
  };
}
// (
  # WireGuard設定を共通モジュールから適用
  sopsWireGuardHelper.mkSopsWireGuardConfig { inherit config pkgs lib; } {
    sopsFile = "${inputs.self}/secrets/wireguard.yaml";
    privateKeyPath = cfg.wireguard.nixos.privateKeyPath;
    publicKeyPath = cfg.wireguard.nixos.publicKeyPath;
    interfaceName = cfg.wireguard.nixos.interfaceName;
    interfaceAddress = "${cfg.wireguard.nixos.clientIp}/24";
    peerEndpoint = cfg.wireguard.nixos.serverEndpoint;
    peerAllowedIPs = [ "${cfg.wireguard.network.serverIp}/32" ];
    persistentKeepalive = cfg.wireguard.persistentKeepalive;
    isDarwin = false;
  }
)

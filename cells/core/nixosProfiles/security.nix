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
    age.keyFile = "/var/lib/sops-nix/key.txt";

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
    privateKeyPath = "wireguard/home/nixosClientPrivKey";
    publicKeyPath = "wireguard/home/publicKey";
    interfaceName = "wg0";
    interfaceAddress = "10.100.0.4/24";
    peerEndpoint = "192.168.1.1:13231";
    peerAllowedIPs = [ "10.100.0.1/32" ];
    persistentKeepalive = 25;
    isDarwin = false;
  }
)

# cells/core/nixosProfiles/wireguard.nix
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

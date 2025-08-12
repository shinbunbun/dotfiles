/*
  Darwin WireGuard設定

  macOS用のWireGuard VPN設定を提供します。
  SOPSを使用した安全な鍵管理を行います。
*/
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = import ../../../shared/config.nix;
  sopsWireGuardHelper = import ../../../secrets/wireguard-helper.nix { inherit inputs; };
in
sopsWireGuardHelper.mkSopsWireGuardConfig { inherit config pkgs lib; } {
  sopsFile = "${inputs.self}/secrets/wireguard.yaml";
  privateKeyPath = cfg.wireguard.darwin.privateKeyPath;
  publicKeyPath = cfg.wireguard.darwin.publicKeyPath;
  endpointPath = cfg.wireguard.darwin.endpointPath;
  interfaceName = cfg.wireguard.darwin.interfaceName;
  interfaceAddress = "${cfg.wireguard.darwin.clientIp}/32";
  peerAllowedIPs = cfg.wireguard.darwin.allowedNetworks ++ [ "${cfg.wireguard.network.serverIp}/32" ];
  persistentKeepalive = cfg.wireguard.persistentKeepalive;
  isDarwin = true;
}
// {
  # Darwin用のSOPS基本設定
  sops = {
    defaultSopsFile = "${inputs.self}/secrets/wireguard.yaml";
    age.keyFile = cfg.sops.keyFile;
  };
}

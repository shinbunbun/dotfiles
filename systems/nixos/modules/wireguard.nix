/*
  WireGuard VPN設定モジュール

  このモジュールはWireGuard VPNの設定を提供します：
  - SOPSを使用したセキュアな鍵管理
  - 自動的なインターフェース設定
  - ピア設定（サーバーとの接続）
  - ルーティング設定

  sops-wireguard.nixヘルパーを使用して、NixOSとDarwinで
  共通の設定を実現します。config.nixの値を参照して
  クライアント固有の設定を行います。
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  sopsWireGuardHelper = import ../../../secrets/wireguard-helper.nix { inherit inputs; };
  cfg = import ../../../shared/config.nix;
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

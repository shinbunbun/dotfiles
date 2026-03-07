/*
  WireGuard VPN設定セクション

  共通ネットワーク設定、NixOS/Darwin固有の接続情報、
  keepalive設定を定義します。
*/
v: {
  wireguard = {
    # 共通設定
    network = {
      subnet = v.assertCIDR "wireguard.network.subnet" "10.100.0.0/24";
      serverIp = v.assertIP "wireguard.network.serverIp" "10.100.0.1";
    };

    # NixOS用設定
    nixos = {
      interfaceName = v.assertString "wireguard.nixos.interfaceName" "wg0";
      clientIp = v.assertIP "wireguard.nixos.clientIp" "10.100.0.4";
      serverEndpoint = v.assertString "wireguard.nixos.serverEndpoint" "192.168.1.1:13231";
      privateKeyPath = v.assertString "wireguard.nixos.privateKeyPath" "wireguard/home/nixosClientPrivKey";
      publicKeyPath = v.assertString "wireguard.nixos.publicKeyPath" "wireguard/home/publicKey";
    };

    # Darwin(macOS)用設定
    darwin = {
      interfaceName = v.assertString "wireguard.darwin.interfaceName" "wg-home";
      clientIp = v.assertIP "wireguard.darwin.clientIp" "10.100.0.2";
      privateKeyPath = v.assertString "wireguard.darwin.privateKeyPath" "wireguard/home/macClientPrivKey";
      publicKeyPath = v.assertString "wireguard.darwin.publicKeyPath" "wireguard/home/publicKey";
      endpointPath = v.assertString "wireguard.darwin.endpointPath" "wireguard/home/endpoint";
      allowedNetworks = v.assertListOf "wireguard.darwin.allowedNetworks" [
        "192.168.1.0/24"
        "10.100.0.0/24"
      ] v.assertCIDR;
    };

    # 共通のkeepalive設定
    persistentKeepalive = v.assertPositiveInt "wireguard.persistentKeepalive" 25;
  };
}

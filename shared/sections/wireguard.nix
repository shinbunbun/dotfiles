/*
  WireGuard VPN設定セクション

  共通ネットワーク設定、NixOS固有の接続情報、keepalive設定を定義します。
  （macOS は WireGuard GUI アプリで管理するため nix 側の CLI 設定は持たない）
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

    # 共通のkeepalive設定
    persistentKeepalive = v.assertPositiveInt "wireguard.persistentKeepalive" 25;
  };
}

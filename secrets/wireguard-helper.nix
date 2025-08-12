/*
  SOPS + WireGuard共通設定ヘルパー

  このモジュールはNixOSとDarwinでWireGuard設定を
  共通化するためのヘルパー関数を提供します：

  mkSopsWireGuardConfig:
  - SOPSを使用した秘密鍵管理
  - WireGuardインターフェースの設定
  - ピア設定とルーティング
  - Darwin用の特別な設定対応

  このヘルパーを使用することで、WireGuard設定の
  重複を避け、一貫性を保ちます。
*/
{ inputs }:
let
  mkSopsWireGuardConfig =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      sopsFile,
      privateKeyPath,
      publicKeyPath,
      endpointPath ? null,
      interfaceName,
      interfaceAddress,
      peerEndpoint ? null,
      peerAllowedIPs,
      persistentKeepalive ? 25,
      isDarwin ? false,
    }:
    let
      configPath = "/etc/wireguard/${interfaceName}.conf";
    in
    {
      sops = {
        secrets = lib.mkMerge [
          {
            ${privateKeyPath} = {
              inherit sopsFile;
            };
            ${publicKeyPath} = {
              inherit sopsFile;
            };
          }
          (lib.optionalAttrs (endpointPath != null) {
            ${endpointPath} = {
              inherit sopsFile;
            };
          })
        ];

        templates."wireguard/${interfaceName}.conf" = {
          content = lib.generators.toINI { } {
            Interface = {
              PrivateKey = config.sops.placeholder.${privateKeyPath};
              Address = interfaceAddress;
            };
            Peer = {
              PublicKey = config.sops.placeholder.${publicKeyPath};
              Endpoint = if peerEndpoint != null then peerEndpoint else config.sops.placeholder.${endpointPath};
              AllowedIPs = lib.concatStringsSep ", " peerAllowedIPs;
              PersistentKeepalive = persistentKeepalive;
            };
          };
          path = configPath;
          owner = "root";
          group = if isDarwin then "wheel" else "root";
          mode = "0600";
        };
      };

      environment.systemPackages = [ pkgs.wireguard-tools ];
    }
    // (lib.optionalAttrs (!isDarwin) {
      networking.wg-quick.interfaces.${interfaceName} = {
        configFile = configPath;
      };
    });
in
{
  inherit mkSopsWireGuardConfig;
}

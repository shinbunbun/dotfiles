# cells/core/sops-wireguard.nix
# SOPS and WireGuard shared configuration helper
{ inputs, cell }:
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
          content = ''
            [Interface]
            PrivateKey = ${config.sops.placeholder.${privateKeyPath}}
            Address = ${interfaceAddress}

            [Peer]
            PublicKey = ${config.sops.placeholder.${publicKeyPath}}
            ${
              if peerEndpoint != null then
                "Endpoint = ${peerEndpoint}"
              else
                "Endpoint = ${config.sops.placeholder.${endpointPath}}"
            }
            AllowedIPs = ${lib.concatStringsSep ", " peerAllowedIPs}
            PersistentKeepalive = ${toString persistentKeepalive}
          '';
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

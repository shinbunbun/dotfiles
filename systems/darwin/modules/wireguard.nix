/*
  Darwin WireGuard設定

  macOS用のWireGuard VPN設定を提供します。
  Home-Manager経由でSOPSテンプレートを生成し、
  システムレベルでWireGuardが使用できるようにします。
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
  username = cfg.users.darwin.username;
  interfaceName = cfg.wireguard.darwin.interfaceName;
  homeDir = cfg.users.darwin.homeDirectory;
  wireguardConfigPath = "${homeDir}/.config/wireguard/${interfaceName}.conf";
in
{
  # WireGuardツールのインストール
  environment.systemPackages = [ pkgs.wireguard-tools ];

  # Home-Manager内でSOPSテンプレートを設定
  home-manager.users.${username} =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.homeManagerModules.sops ];

      sops = {
        defaultSopsFile = "${inputs.self}/secrets/wireguard.yaml";
        age.keyFile = cfg.sops.keyFile;

        # 個別のシークレット定義
        secrets = {
          "wireguard/home/macClientPrivKey" = { };
          "wireguard/home/publicKey" = { };
          "wireguard/home/endpoint" = { };
        };

        # WireGuard設定テンプレート
        templates."wireguard-config" = {
          content = ''
            [Interface]
            PrivateKey = ${config.sops.placeholder."wireguard/home/macClientPrivKey"}
            Address = ${cfg.wireguard.darwin.clientIp}/32

            [Peer]
            PublicKey = ${config.sops.placeholder."wireguard/home/publicKey"}
            Endpoint = ${config.sops.placeholder."wireguard/home/endpoint"}
            AllowedIPs = ${
              lib.concatStringsSep ", " (
                cfg.wireguard.darwin.allowedNetworks ++ [ "${cfg.wireguard.network.serverIp}/32" ]
              )
            }
            PersistentKeepalive = ${toString cfg.wireguard.persistentKeepalive}
          '';
          path = wireguardConfigPath;
          mode = "0600";
        };
      };

      # WireGuard管理用のエイリアス
      programs.zsh.shellAliases = {
        wg-up = "sudo wg-quick up ${interfaceName}";
        wg-down = "sudo wg-quick down ${interfaceName}";
        wg-status = "sudo wg show ${interfaceName}";
      };
    };

  # システムレベルでWireGuard設定をセットアップ
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Setting up WireGuard configuration..." >&2

    # 設定ディレクトリ作成
    mkdir -p /usr/local/etc/wireguard

    # Home-Managerが生成した設定ファイルが存在するか確認
    if [ -f "${wireguardConfigPath}" ]; then
      # システムレベルにコピー
      cp "${wireguardConfigPath}" "/usr/local/etc/wireguard/${interfaceName}.conf"
      chmod 600 "/usr/local/etc/wireguard/${interfaceName}.conf"
      echo "WireGuard configuration copied to /usr/local/etc/wireguard/${interfaceName}.conf" >&2
    else
      echo "Warning: WireGuard configuration not found at ${wireguardConfigPath}" >&2
      echo "Home-Manager activation may be needed first" >&2
    fi
  '';
}

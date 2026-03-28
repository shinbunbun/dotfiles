/*
  管理インターフェース設定セクション

  Cockpit、ttyd、アクセス制限、Cloudflare Tunnelの設定を定義します。
*/
v: {
  management = {
    # Cockpit設定
    cockpit = {
      enable = v.assertBool "management.cockpit.enable" true;
      port = v.assertPort "management.cockpit.port" 9091;
      domain = v.assertString "management.cockpit.domain" "cockpit.shinbunbun.com";
    };

    # ttyd設定
    ttyd = {
      enable = v.assertBool "management.ttyd.enable" true;
      port = v.assertPort "management.ttyd.port" 7681;
      domain = v.assertString "management.ttyd.domain" "terminal.shinbunbun.com";
      passwordFile = v.assertPath "management.ttyd.passwordFile" "/var/lib/ttyd/password";
    };

    # アクセス制限設定
    access = {
      allowedNetworks = v.assertListOf "management.access.allowedNetworks" [
        "192.168.1.0/24"
        "192.168.11.0/24"
        "10.100.0.0/24" # WireGuard
      ] v.assertCIDR;
      wireguardInterface = v.assertString "management.access.wireguardInterface" "wg0";
    };
  };

  cloudflare = {
    # nixos-desktop用トンネル設定
    desktop = {
      cockpit = {
        domain = v.assertString "cloudflare.desktop.cockpit.domain" "desktop-cockpit.shinbunbun.com";
      };
      ttyd = {
        domain = v.assertString "cloudflare.desktop.ttyd.domain" "desktop-terminal.shinbunbun.com";
      };
      calendarBot = {
        domain = v.assertString "cloudflare.desktop.calendarBot.domain" "calendar-bot.shinbunbun.com";
      };
      mixi2Bot = {
        domain = v.assertString "cloudflare.desktop.mixi2Bot.domain" "mixi2-bot.shinbunbun.com";
      };
      argocd = {
        domain = v.assertString "cloudflare.desktop.argocd.domain" "argocd.shinbunbun.com";
      };
      nextcloud = {
        domain = v.assertString "cloudflare.desktop.nextcloud.domain" "nextcloud.shinbunbun.com";
      };
      immich = {
        domain = v.assertString "cloudflare.desktop.immich.domain" "immich.shinbunbun.com";
      };
    };
  };
}

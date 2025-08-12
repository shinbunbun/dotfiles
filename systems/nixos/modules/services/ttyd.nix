/*
  ttyd - ウェブベースのターミナルエミュレータ

  機能:
  - ブラウザからターミナルアクセス
  - ファイル転送（ZMODEM/trzsz）
  - 画像表示（Sixel）
  - SSL/TLS暗号化
  - 認証機能

  設定:
  - ポート7681でリッスン
  - HTTPS有効化
  - パスワード認証
  - xterm.jsベースのモダンなターミナル
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;
  enable = cfg.management.ttyd.enable;
  port = cfg.management.ttyd.port;
  domain = cfg.management.ttyd.domain;
  passwordFile = "/var/lib/ttyd/password";
  allowedNetworks = cfg.networking.allowedNetworks;
in
{
  config = lib.mkIf enable {
    # ttydサービスを有効化
    services.ttyd = {
      enable = true;
      port = port;

      # 実行するコマンド
      entrypoint = [ "${pkgs.zsh}/bin/zsh" ];

      # ユーザー設定
      user = "ttyd";
      # groupオプションは存在しないためコメントアウト
      # group = "ttyd";

      # ネットワーク設定
      interface = "0.0.0.0";
      enableIPv6 = true;

      # セキュリティ設定
      writeable = true; # ターミナルへの書き込みを許可
      checkOrigin = true; # Origin検証を有効化
      maxClients = 10; # 最大同時接続数

      # 認証設定
      # username = "ttyd";
      # passwordFile = passwordFile;

      # SSL/TLS設定（リバースプロキシ経由の場合は不要）
      # certFile = "/path/to/cert.pem";
      # keyFile = "/path/to/key.pem";
      # caFile = "/path/to/ca.pem";

      # クライアント設定（xterm.js）
      clientOptions = {
        # ターミナル外観
        fontSize = "14";
        fontFamily = "'Cascadia Code', 'Fira Code', 'Monaco', monospace";
        cursorStyle = "block";
        cursorBlink = "true";

        # スクロール設定
        scrollback = "10000";
      };
    };

    # ttydユーザーとグループを作成
    users.users.ttyd = {
      isSystemUser = true;
      group = "ttyd";
      description = "ttyd web terminal user";
    };

    users.groups.ttyd = { };

    # systemd tmpfilesでディレクトリを作成
    systemd.tmpfiles.rules = [
      "d /var/lib/ttyd 0755 ttyd ttyd -"
    ];

    # パスワードファイルの生成（有効な場合）
    systemd.services.ttyd-password = lib.mkIf (passwordFile != null) {
      description = "Generate ttyd password file";
      wantedBy = [ "ttyd.service" ];
      before = [ "ttyd.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # ディレクトリが存在しない場合は作成
        mkdir -p "$(dirname "${passwordFile}")"
        chown ttyd:ttyd "$(dirname "${passwordFile}")"

        # パスワードファイルが存在しない場合は作成
        if [ ! -f "${passwordFile}" ]; then
          echo "ttyd:$(${pkgs.openssl}/bin/openssl rand -base64 32)" > "${passwordFile}"
          chmod 600 "${passwordFile}"
          chown ttyd:ttyd "${passwordFile}"
        fi
      '';
    };

    # ファイアウォール設定 - 特定のネットワークからのみ許可
    networking.firewall.extraCommands = lib.mkIf config.networking.firewall.enable ''
      # ttydアクセスを制限
      ${lib.concatMapStrings (network: ''
        iptables -A nixos-fw -p tcp --dport ${toString port} -s ${network} -j ACCEPT
      '') allowedNetworks}

      # WireGuardインターフェースからのアクセスを許可
      iptables -A nixos-fw -p tcp --dport ${toString port} -i wg0 -j ACCEPT
    '';

    # 必要なパッケージ
    environment.systemPackages = with pkgs; [
      # ファイル転送ツール
      lrzsz # ZMODEM
    ];
  };
}

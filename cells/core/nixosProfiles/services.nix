# cells/core/nixosProfiles/services.nix
{ inputs, cell }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = import ../config.nix;
in
{
  # SSH service with enhanced security
  services.openssh = {
    enable = true;
    ports = [ cfg.ssh.port ];
    settings = {
      # 基本的なセキュリティ設定
      X11Forwarding = true; # X11転送は有効のまま
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false; # キーボード対話認証を無効化
      UsePAM = true;

      # 接続制限
      MaxAuthTries = 3; # 認証試行回数の制限
      MaxSessions = 10; # 最大セッション数
      ClientAliveInterval = 1800; # 30分ごとにクライアントの生存確認
      ClientAliveCountMax = 3; # 3回応答がない場合は切断（合計90分）

      # ログ設定
      LogLevel = "VERBOSE"; # 詳細なログを記録

      # その他のセキュリティ設定
      StrictModes = true; # ファイル権限の厳格なチェック
      IgnoreRhosts = true; # .rhostsファイルを無視
      HostbasedAuthentication = false; # ホストベース認証を無効化
      PermitEmptyPasswords = false; # 空パスワードを禁止
      PermitUserEnvironment = false; # ユーザー環境変数の設定を禁止
    };

    extraConfig = ''
      AuthorizedKeysFile ${cfg.ssh.authorizedKeysPath}

      # 特定のユーザーグループのみSSHアクセスを許可
      AllowGroups wheel

      # バナーメッセージ（オプション）
      Banner /etc/ssh/banner

      # 暗号化アルゴリズムの設定（強力なもののみを使用）
      # 鍵交換アルゴリズム
      KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

      # 暗号化アルゴリズム
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

      # MACアルゴリズム
      MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

      # ホスト鍵アルゴリズム
      HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
    '';
  };

  # SSHバナーファイルの作成
  environment.etc."ssh/banner" = {
    text = ''
      ********************************************************************
      *                        WARNING NOTICE                            *
      *                                                                  *
      * This system is for authorized use only. All activities are      *
      * monitored and logged. Unauthorized access is prohibited and     *
      * will be prosecuted to the fullest extent of the law.           *
      ********************************************************************
    '';
    mode = "0644";
  };

  # Fail2ban for SSH protection with enhanced configuration
  services.fail2ban = {
    enable = true;
    ignoreIP = cfg.fail2ban.ignoreNetworks;

    # SSH jail の詳細設定 (デフォルト設定を上書き)
    jails.sshd.settings = {
      enabled = true;
      port = cfg.ssh.port;
      filter = "sshd[mode=aggressive]";
      maxretry = 3;
      findtime = 600;
      bantime = 3600;
      action = ''iptables[name=SSH, port="${toString cfg.ssh.port}", protocol=tcp]'';
    };
  };

  # Docker
  virtualisation.docker.enable = true;
}

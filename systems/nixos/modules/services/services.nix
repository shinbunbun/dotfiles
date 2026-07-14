/*
  サービス設定モジュール

  このモジュールは以下のサービスを設定します：
  - OpenSSHサーバー（セキュリティ強化設定付き）
    → SSH の強化設定本体は ./sshd-baseline.nix に分離し、ここでは import する。
      複数ホストで共有する SSH ベースラインを一元管理するため。
  - Fail2ban（SSH保護）
    - ブルートフォース攻撃からの保護
    - 設定可能な除外ネットワーク
  - ファイアウォール（SSHポートの開放）
  - Dockerコンテナランタイム

  config.nixの値を参照して設定を行います。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;
in
{
  imports = [
    # SSH の強化設定 (services.openssh + banner) を提供するベースライン
    ./sshd-baseline.nix
  ];

  # ファイアウォール設定 - SSHポートを許可
  networking.firewall.allowedTCPPorts = [ cfg.ssh.port ];

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

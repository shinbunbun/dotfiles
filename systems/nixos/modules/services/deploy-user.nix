/*
  デプロイ専用ユーザー設定モジュール

  このモジュールはCI/CDからの自動デプロイ用ユーザーを提供します：
  - deploy-rs用の専用ユーザー
  - 限定的なNOPASSWD sudo権限（switch-to-configurationのみ）
  - SSH公開鍵認証

  セキュリティ:
  - bunbunユーザーとは分離
  - 最小権限の原則に従う
  - SSH鍵が漏洩しても影響を限定
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  cfg = import ../../../../shared/config.nix;
in
{
  # SOPS シークレット設定（既存のsecurity.nixと同じアプローチ）
  sops.secrets."deploy_ssh_public_key" = {
    sopsFile = "${inputs.self}/secrets/deploy.yaml";
    # /etc/ssh/authorized_keys.d/%u にファイルを配置（SSHdが自動的に読み取る）
    path = "/etc/ssh/authorized_keys.d/${cfg.deploy.user}";
    owner = cfg.deploy.user;
    mode = "0444";
    neededForUsers = true;
  };

  # デプロイ専用ユーザー
  users.users.${cfg.deploy.user} = {
    isNormalUser = true;
    description = "Automated deployment user for CI/CD";
    # SSH公開鍵は上記のSOPS secretで /etc/ssh/authorized_keys.d/deploy に配置
    # SSHdのAuthorizedKeysFileが /etc/ssh/authorized_keys.d/%u なので自動的に読み取られる
    shell = pkgs.bash;
  };

  # 限定的なNOPASSWD sudo権限
  security.sudo.extraRules = [
    {
      users = [ cfg.deploy.user ];
      commands = [
        {
          command = "/nix/store/*/bin/switch-to-configuration *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nix-env *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/nix/store/*/bin/nix-env *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}

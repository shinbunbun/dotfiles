/*
  デプロイ専用ユーザー設定モジュール

  このモジュールはCI/CDからの自動デプロイ用ユーザーを提供します：
  - deploy-rs用の専用ユーザー
  - wheelグループへの所属（SSH AllowGroups制限を通過するため）
  - Nix trusted-user権限（Nixストアへのアクセスとクロージャ転送のため）
  - NOPASSWD sudo権限（deploy-rsのactivationに必要）
  - SSH公開鍵認証

  セキュリティ:
  - bunbunユーザーとは分離
  - SSH公開鍵認証のみ（秘密鍵はGitHub Secretsで管理）
  - CI/CDからのアクセスのみを想定
  - trusted-user権限は必要だが、アクセス経路が限定的
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
    extraGroups = [ "wheel" ]; # SSH AllowGroups制限を通過するため
  };

  # Nix trusted-user設定（クロージャ転送のため必要）
  nix.settings.trusted-users = [ cfg.deploy.user ];

  # deploy-rs用のNOPASSWD sudo権限
  security.sudo.extraRules = [
    {
      users = [ cfg.deploy.user ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}

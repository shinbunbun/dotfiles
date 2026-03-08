/*
  Darwin用デプロイ専用ユーザー設定モジュール

  CI/CDからの自動デプロイ用ユーザー設定を提供します：
  - deploy ユーザーの SSH 公開鍵認証（activation script 経由）
  - Nix trusted-user 権限
  - NOPASSWD sudo 権限（deploy-rs の activation に必要）

  前提条件:
  - deploy ユーザーは macOS 上で手動作成が必要（dscl コマンド）
  - SSH 公開鍵は SOPS で管理
*/
{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = import ../../../shared/config.nix;
  deployUser = cfg.deploy.user;
in
{
  # SOPS シークレット
  sops.secrets."deploy_ssh_public_key" = {
    sopsFile = "${inputs.self}/secrets/deploy.yaml";
    mode = "0444";
  };

  # SSH authorized_keys を activation script で配置
  # nix-darwin の keyFiles はビルド時にファイルを読むため、SOPS ランタイムパスが使えない
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # deploy ユーザーの SSH authorized_keys を SOPS シークレットから配置
    if [ -d /Users/${deployUser} ]; then
      mkdir -p /Users/${deployUser}/.ssh
      cp ${config.sops.secrets."deploy_ssh_public_key".path} /Users/${deployUser}/.ssh/authorized_keys
      chown -R ${deployUser}:staff /Users/${deployUser}/.ssh
      chmod 700 /Users/${deployUser}/.ssh
      chmod 600 /Users/${deployUser}/.ssh/authorized_keys
    fi
  '';

  # Nix trusted-user 設定
  nix.settings.trusted-users = [ deployUser ];

  # NOPASSWD sudo（sudoers.d に配置）
  environment.etc."sudoers.d/deploy" = {
    text = "${deployUser} ALL=(ALL) NOPASSWD: ALL";
  };
}

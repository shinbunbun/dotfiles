/*
  GitHub Actions Self-Hosted Runner 設定 - macmini (Darwin)

  dotfiles-private リポジトリ用のセルフホステッドランナーを定義します。
  ローカルネットワーク上の Attic キャッシュへ直接アクセスし、
  既存の Nix 環境を活用してビルドを実行します。
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  sops.secrets."github_runner_token" = {
    sopsFile = "${inputs.self}/secrets/github-runner.yaml";
    owner = "_github-runner";
  };

  # 既存の _github-runner ユーザーのホームディレクトリに合わせる
  # nix-darwin は既存ユーザーのホームディレクトリ変更を許可しないため明示的に指定
  users.users._github-runner.home = lib.mkForce "/private/var/lib/github-runners";

  services.github-runners.dotfiles-private = {
    enable = true;
    # aarch64-darwin でテストがタイムアウトするため doCheck を無効化
    package = pkgs.github-runner.overrideAttrs { doCheck = false; };
    url = "https://github.com/shinbunbun/dotfiles-private";
    tokenFile = config.sops.secrets."github_runner_token".path;
    name = "macmini";
    extraLabels = [
      "darwin"
      "aarch64-darwin"
    ];
    replace = true;
    ephemeral = true;
    nodeRuntimes = [ "node24" ];
    extraPackages = with pkgs; [
      nix
      nixfmt-tree
      git
      bash
      coreutils
      gnutar
      gzip
      curl
      jq
      openssh
    ];
    extraEnvironment = {
      NIX_CONFIG = "experimental-features = nix-command flakes";
    };
    # launchd の再起動ポリシーを上書きし、runner を自己復旧可能にする。
    #
    # モジュール既定では ephemeral runner の KeepAlive が
    # `{ SuccessfulExit = true; }`（正常終了時のみ再起動）となるため、
    # 一時的なエラー（boot 時の sops secret race、GitHub broker への SSL 失敗等）で
    # 非0終了すると launchd が再起動せず、runner が offline のまま固定される。
    #
    # `KeepAlive = true`（終了コードに関わらず常に再起動、ThrottleInterval=30 で
    # 最短30秒間隔）にすることで、
    #   - ジョブ完了(exit 0) → 再起動して再登録（ephemeral 本来の挙動）
    #   - 一時エラー(exit≠0) → 30秒後に再起動して自己復旧
    # の両方を満たす。恒久エラー（token 失効等）の場合は30秒毎にリトライし続け、
    # ログと GitHub 上の offline 表示で問題が露出する（silent failure を防ぐ）。
    serviceOverrides = {
      KeepAlive = lib.mkForce true;
    };
  };
}

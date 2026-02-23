/*
  GitHub Actions Self-Hosted Runner 設定 - macmini (Darwin)

  dotfiles-private リポジトリ用のセルフホステッドランナーを定義します。
  ローカルネットワーク上の Attic キャッシュへ直接アクセスし、
  既存の Nix 環境を活用してビルドを実行します。
*/
{
  config,
  pkgs,
  inputs,
  ...
}:
{
  sops.secrets."github_runner_token" = {
    sopsFile = "${inputs.self}/secrets/github-runner.yaml";
    owner = "_github-runner";
  };

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
    nodeRuntimes = [ "node20" ];
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
  };
}

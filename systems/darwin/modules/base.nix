/*
  Darwin基本設定モジュール

  macOSシステムの基本設定を提供します：
  - システムバージョン設定
  - Nix設定（sandbox、trusted-users）
  - Homebrew PATH設定
*/
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = import ../../../shared/config.nix;
in
{
  system.stateVersion = 5;
  system.primaryUser = cfg.users.darwin.username;

  nix.settings = {
    # macOS推奨: Fixed-output derivations（npm依存関係など）をサンドボックスから除外
    # これによりDNS解決とネットワークアクセスが正常に動作する
    sandbox = "relaxed";
    trusted-users = [
      "@admin"
      "_github-runner"
    ];
    allowed-users = [
      "@admin"
      "_github-runner"
    ];

    # Attic バイナリキャッシュ設定（プライベート）
    substituters = [
      "https://cache.nixos.org"
      "https://${cfg.attic.domain}/main"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "main:EMoov6FniyxjYhY24OcZ02dOIWKu4feJH7uGRjgwwUc="
    ];

    # プライベートキャッシュの認証用netrc
    # Darwin: ~/.netrcに手動で設定する必要があります
    # netrc-file = "/run/secrets/nix-netrc";  # NixOS only
  };

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Homebrewのパスを環境変数に追加
  environment.systemPath = [ "/opt/homebrew/bin" ];

  # HTML マニュアル(darwin-manual-html)のビルドを暫定的に無効化する。
  # nixpkgs の nixos-render-docs が --toc-depth を廃止(--sidebar-depth へ)した一方、
  # nix-darwin が未追随のため darwin-manual-html のビルドが失敗する。
  # 上流修正 (LnL7/nix-darwin#1817 / PR #1818 / #1819) がマージされ次第、この設定を撤去すること。
  # man ページ(documentation.man)は影響を受けないため据え置く。
  documentation.doc.enable = false;
}

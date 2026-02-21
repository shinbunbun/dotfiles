/*
  Darwin基本設定モジュール

  macOSシステムの基本設定を提供します：
  - システムバージョン設定
  - Nix設定（sandbox、trusted-users）
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
    trusted-users = [ "@admin" ];
    allowed-users = [ "@admin" ];

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
}

/*
  Immich - 写真・動画管理サーバー

  機能:
  - 写真・動画の自動バックアップ（iOS/Android対応）
  - 顔認識・オブジェクト認識（ML）
  - Intel GPU (OpenVINO) によるML高速化

  設定:
  - shared/config.nix の immich セクションで有効化
  - ポートはデフォルト2283
  - mediaLocation はホスト固有設定で指定
*/
{ lib, ... }:
let
  cfg = import ../../../../shared/config.nix;
  enable = cfg.immich.enable;
in
{
  config = lib.mkIf enable {
    services.immich = {
      enable = true;
      port = cfg.immich.port;
      openFirewall = true;
    };
  };
}

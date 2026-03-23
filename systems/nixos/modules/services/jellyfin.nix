/*
  Jellyfin - メディアサーバー

  機能:
  - メディアファイルのストリーミング再生
  - VAAPI によるハードウェアトランスコード

  設定:
  - デフォルトポート8096でリッスン
  - jellyfinユーザーにrender/videoグループ付与（GPU利用）
*/
{ lib, ... }:
let
  cfg = import ../../../../shared/config.nix;
  enable = cfg.jellyfin.enable;
in
{
  config = lib.mkIf enable {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };

    # ハードウェアトランスコード用グループ
    users.users.jellyfin.extraGroups = [
      "render"
      "video"
    ];
  };
}

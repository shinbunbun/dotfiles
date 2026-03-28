/*
  Jellyfin - メディアサーバー

  機能:
  - メディアファイルのストリーミング再生
  - VAAPI によるハードウェアトランスコード

  設定:
  - デフォルトポート8096でリッスン
  - jellyfinユーザーにrender/videoグループ付与（GPU利用）
*/
{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.services.jellyfin.enable {
    services.jellyfin = {
      openFirewall = true;
    };

    # ハードウェアトランスコード用グループ
    users.users.jellyfin.extraGroups = [
      "render"
      "video"
    ];
  };
}

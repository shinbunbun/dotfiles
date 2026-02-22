/*
  Darwin画面共有設定

  macOSの画面共有（Screen Sharing / VNC）を有効化します。
  nix-darwinには画面共有の組み込みオプションがないため、
  アクティベーションスクリプトでlaunchctlを使い画面共有サービスを有効化します。

  有効化後、VNCクライアントまたはmacOSの画面共有アプリから
  ユーザーアカウントの資格情報で接続できます（ポート5900）。
*/
{ lib, ... }:

let
  plist = "/System/Library/LaunchDaemons/com.apple.screensharing.plist";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Enabling Screen Sharing..." >&2
    launchctl load -w ${plist} 2>/dev/null || true
    echo "Screen Sharing enabled." >&2
  '';
}

/*
  Darwin画面共有設定

  macOSの画面共有（Screen Sharing / VNC）を有効化します。
  nix-darwinには画面共有の組み込みオプションがないため、
  アクティベーションスクリプトでAppleのRemote Managementを有効化します。

  有効化後、VNCクライアントまたはmacOSの画面共有アプリから
  ユーザーアカウントの資格情報で接続できます（ポート5900）。
*/
{ lib, ... }:

let
  cfg = import ../../../shared/config.nix;
  username = cfg.users.darwin.username;
  kickstart = "/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart";
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Enabling Screen Sharing..." >&2
    ${kickstart} \
      -activate \
      -configure \
      -access -on \
      -restart -agent \
      -privs -all \
      -allowAccessFor -specifiedUsers \
      -users ${username} \
      2>&1 | while IFS= read -r line; do echo "  [Screen Sharing] $line" >&2; done
    echo "Screen Sharing enabled for user: ${username}" >&2
  '';
}

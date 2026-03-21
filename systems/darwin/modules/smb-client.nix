/*
  macOS SMBクライアント設定

  機能:
  - SMBマルチチャネルの無効化（mc_on=no）

  背景:
  - macOSのSMBマルチチャネル実装は不完全で、シングルNICサーバーに対して
    smb2_mc_update_main_channel / smb_iod_start_reconnect エラーを引き起こす
  - サーバー側で無効化しても、macOSクライアントは定期的にインターフェーススキャンを試行する
*/
{ ... }:
{
  environment.etc."nsmb.conf" = {
    text = ''
      [default]
      mc_on=no
    '';
  };
}

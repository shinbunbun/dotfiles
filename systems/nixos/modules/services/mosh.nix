/*
  Mosh（Mobile Shell）設定モジュール

  このモジュールはMoshの設定を行います：
  - Moshパッケージのインストール
  - UDPファイアウォールポートの自動開放（60000-61000）
  - utempterサポート（ユーザーセッション追跡）
*/
{ ... }:
{
  programs.mosh.enable = true;
}

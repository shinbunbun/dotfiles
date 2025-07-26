/*
  コアhome-managerプロファイルモジュール

  このモジュールは基本的なhome-manager設定を提供します：
  - default: 基本設定
    - home.stateVersion: home-managerのステートバージョン
    - xdg.enable: XDG Base Directory仕様の有効化

  このプロファイルはすべてのhome-manager設定の
  基盤として使用されます。
*/
{
  inputs,
  cell,
}:
{
  default = {
    home.stateVersion = "24.11";

    xdg.enable = true;
  };
}

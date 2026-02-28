/*
  tmux設定モジュール

  ターミナルマルチプレクサtmuxの設定を提供します：
  - マウス操作対応（ペイン選択・リサイズ・スクロール）
  - 直感的なキーバインド（| で縦分割、- で横分割）
  - システムクリップボード連携（tmux-yank）
  - 基本設定の改善（tmux-sensible）

  使い方:
    tmux           - 新しいセッションを開始
    tmux attach    - 既存セッションに接続
    prefix + |     - 縦分割
    prefix + -     - 横分割
    prefix + r     - 設定リロード
*/
{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;

    # マウスでペイン選択・リサイズ・スクロール可能
    mouse = true;

    # コピーモードで矢印キーベースの操作
    keyMode = "emacs";

    # 24時間表示
    clock24 = true;

    # スクロールバック行数
    historyLimit = 50000;

    # ウィンドウ/ペイン番号を1始まりに（キーボード配置に合わせる）
    baseIndex = 1;

    # Escキーの遅延を短縮（ms）
    escapeTime = 10;

    # 256色対応
    terminal = "tmux-256color";

    # プラグイン
    plugins = with pkgs.tmuxPlugins; [
      sensible # 基本的なデフォルト設定の改善
      yank # システムクリップボードへのコピー対応
    ];

    # 追加キーバインド
    extraConfig = ''
      # 直感的なペイン分割
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # 設定リロード
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "設定をリロードしました"

      # ペイン番号も1始まりに
      setw -g pane-base-index 1
    '';
  };
}

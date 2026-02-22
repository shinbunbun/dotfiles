/*
  シェルツール設定モジュール

  このモジュールはシェル環境を強化するツールを提供します：
  - zsh: メインシェル（補完、自動サジェスト機能付き）
  - lsd: lsコマンドの高機能版
  - starship: プロンプトのカスタマイズ
  - direnv: ディレクトリ固有の環境変数設定

  starshipはステータス表示と時刻表示が有効化されています。
*/
{ pkgs, config, ... }:
{
  # zsh config
  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    autosuggestion.enable = true;
    plugins = [
      {
        name = "zsh-completions";
        src = pkgs.zsh-completions.src;
      }
      {
        name = "nix-zsh-completions";
        src = pkgs.nix-zsh-completions.src;
      }
    ];
  };

  # LSD config
  programs.lsd = {
    enable = true;
  };

  # starship config
  programs.starship = {
    enable = true;
    settings = {
      status = {
        disabled = false;
      };
      time = {
        disabled = false;
        utc_time_offset = "+9";
        time_format = "%Y-%m-%d %H:%M";
      };
    };
  };

  # direnv config
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };
}

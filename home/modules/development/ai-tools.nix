/*
  AIツール設定モジュール

  このモジュールはAI関連のツールを提供します：
  - claude-code: Claudeの公式CLIツール
  - mcp-grafana: Grafana MCPサーバー（Claude CodeからGrafana/Loki/Prometheusへのクエリ実行用）
  - github-mcp-server: GitHub MCPサーバー（Claude CodeからGitHub APIへの直接アクセス用）

  Claudeのグローバル設定ファイル（CLAUDE.md）も配置し、
  日本語での応答をデフォルト設定としています。
*/
{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    [
      mcp-grafana
      github-mcp-server
    ]
    ++ lib.optionals stdenv.isLinux [
      claude-code
    ];

  home.file.".claude/CLAUDE.md" = {
    text = ''
      ユーザーには日本語で応答してください。
    '';
  };

  home.file.".claude/statusline.sh" = {
    source = ./claude-statusline.sh;
    executable = true;
  };
}

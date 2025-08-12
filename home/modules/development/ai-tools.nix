/*
  AIツール設定モジュール

  このモジュールはAI関連のツールを提供します：
  - claude-code: Claudeの公式CLIツール

  Claudeのグローバル設定ファイル（CLAUDE.md）も配置し、
  日本語での応答をデフォルト設定としています。
*/
{ pkgs, ... }:
{
  home.packages = [
    pkgs.claude-code
  ];

  home.file.".claude/CLAUDE.md" = {
    text = ''
      ユーザーには日本語で応答してください。
    '';
  };
}

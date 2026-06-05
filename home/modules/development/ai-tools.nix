/*
  AIツール設定モジュール

  このモジュールはAI関連のツールを提供します：
  - claude-code: Claudeの公式CLIツール
  - mcp-grafana: Grafana MCPサーバー（Claude CodeからGrafana/Loki/Prometheusへのクエリ実行用）
  - github-mcp-server: GitHub MCPサーバー（Claude CodeからGitHub APIへの直接アクセス用）
  - uv: Python ツールランナー（mcp-server-motherduck を uvx で起動するため）
  - duckdb: DuckDB CLI（Garage S3 上の Parquet ログアーカイブをローカルで動作確認するため）
  - nodejs: Node.js ランタイム（argoproj-labs/mcp-for-argocd を npx で起動するため）

  Claudeのグローバル設定ファイル（CLAUDE.md）も配置し、
  日本語での応答をデフォルト設定としています。
*/
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    claude-code
    mcp-grafana
    github-mcp-server
    uv
    duckdb
    nodejs_22
  ];

  programs.zsh.initExtra = ''
    if command -v gh &>/dev/null; then
      export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null)"
    fi
    # DuckDB MCP (mcp-server-motherduck) が Garage S3 に read-only でアクセス
    # するための credentials。k8s 上の grafana-duckdb-credentials Secret
    # (GarageKey "grafana-duckdb" の secretTemplate 出力、logs-archive バケット
    # read のみ) をそのまま再利用する。kubectl 不在 / 権限なしの環境では何もしない。
    if command -v kubectl &>/dev/null && kubectl auth can-i get secret/grafana-duckdb-credentials -n grafana &>/dev/null; then
      export GARAGE_DUCKDB_KEY_ID="$(kubectl get secret grafana-duckdb-credentials -n grafana -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' 2>/dev/null | base64 -d 2>/dev/null)"
      export GARAGE_DUCKDB_SECRET="$(kubectl get secret grafana-duckdb-credentials -n grafana -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' 2>/dev/null | base64 -d 2>/dev/null)"
    fi
  '';

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

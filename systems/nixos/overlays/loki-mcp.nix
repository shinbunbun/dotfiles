/*
  Loki MCP Server オーバーレイ

  Grafana公式のLoki MCPサーバーをビルドします。
  Claude CodeからLokiへのLogQLクエリ実行を可能にします。
  https://github.com/grafana/loki-mcp
*/
final: prev: {
  loki-mcp-server = prev.buildGoModule rec {
    pname = "loki-mcp-server";
    version = "0.6.0";

    src = prev.fetchFromGitHub {
      owner = "grafana";
      repo = "loki-mcp";
      rev = "v${version}";
      hash = "sha256-rRnKsE/jiOcvLZ8keN+i5X3nw8Hyx4wdq6w6EpAPjZ0=";
    };

    vendorHash = "sha256-xu9/BBKiUMNUhQQZCaifCoYtu0fkXqyx2aZUGQh2hGQ=";

    subPackages = [ "cmd/server" ];

    # サブパッケージ名 "server" → "loki-mcp-server" にリネーム
    postInstall = ''
      mv $out/bin/server $out/bin/loki-mcp-server
    '';

    meta = with prev.lib; {
      description = "MCP (Model Context Protocol) Server for Grafana Loki";
      homepage = "https://github.com/grafana/loki-mcp";
      license = licenses.asl20;
      mainProgram = "loki-mcp-server";
    };
  };
}

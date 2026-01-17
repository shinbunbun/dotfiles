# Fluent Bit 設定ファイル生成関数
#
# この関数は Fluent Bit の設定ファイルを生成します。
# 引数:
#   pkgs: nixpkgs
#   cfg: config.nix から読み込んだ設定
#   hostname: ホスト名

{
  pkgs,
  cfg,
  hostname,
}:

let
  # Luaスクリプト: RouterOSログレベルマッピング
  luaScript = pkgs.writeText "routeros-severity.lua" ''
    function map_routeros_severity(tag, timestamp, record)
      if record["pri"] then
        local severity = tonumber(record["pri"]) % 8
        local severity_map = {
          [0] = "emergency",
          [1] = "alert",
          [2] = "critical",
          [3] = "error",
          [4] = "warning",
          [5] = "notice",
          [6] = "info",
          [7] = "debug"
        }
        record["level"] = severity_map[severity]
        return 1, timestamp, record
      end
      return 0, timestamp, record
    end
  '';

  # パーサー設定ファイル
  parsersConfig = pkgs.writeText "parsers.conf" ''
    [PARSER]
        Name        nginx
        Format      regex
        Regex       ^(?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^\"]*?)(?: +\S*)?)?" (?<status>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")
        Time_Key    time
        Time_Format %d/%b/%Y:%H:%M:%S %z

    [PARSER]
        Name        nginx_error
        Format      regex
        Regex       ^(?<time>[^ ]+ [^ ]+) \[(?<level>\w+)\] (?<pid>\d+).(?<tid>\d+): (?<message>.*)$
        Time_Key    time
        Time_Format %Y/%m/%d %H:%M:%S

    [PARSER]
        Name        json
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L
        Time_Keep   On

    [PARSER]
        Name        couchdb_level
        Format      regex
        Regex       ^\[(?<extracted_level>[a-z]+)\]
        Time_Keep   On

    [PARSER]
        Name        syslog-rfc3164
        Format      regex
        Regex       ^\<(?<pri>[0-9]+)\>(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
        Time_Key    time
        Time_Format %b %d %H:%M:%S

    [PARSER]
        Name        syslog-rfc3164-notime
        Format      regex
        Regex       ^\<(?<pri>[0-9]+)\>(?<syslog_time>[^ ]* {1,2}[^ ]* [^ ]*) (?<syslog_host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
  '';

  # メイン設定ファイル
  fluentBitConfig = pkgs.writeText "fluent-bit.conf" ''
    [SERVICE]
        Flush        5
        Daemon       Off
        Log_Level    info
        Parsers_File ${parsersConfig}
        HTTP_Server  On
        HTTP_Listen  0.0.0.0
        HTTP_Port    ${toString cfg.fluentBit.port}
        storage.path /var/lib/fluent-bit/

    # systemd-journalからの入力
    [INPUT]
        Name              systemd
        Tag               journal.*
        Read_From_Tail    On
        Strip_Underscores On

    # RouterOS syslogからの入力
    [INPUT]
        Name              syslog
        Tag               syslog
        Mode              udp
        Listen            0.0.0.0
        Port              ${toString cfg.fluentBit.syslogPort}
        Parser            syslog-rfc3164-notime
        Buffer_Chunk_Size 65535

    # systemd-journalログの処理
    [FILTER]
        Name                modify
        Match               journal.*
        Add                 host ${hostname}
        Add                 log_type systemd

    # ログレベルの正規化
    [FILTER]
        Name                modify
        Match               journal.*
        Rename              PRIORITY priority_fallback
        Rename              MESSAGE message
        Rename              SYSLOG_IDENTIFIER service
        Rename              _SYSTEMD_UNIT unit

    # priority_fallbackの数値→文字列変換
    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 0
        Set                 priority_fallback emergency

    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 1
        Set                 priority_fallback alert

    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 2
        Set                 priority_fallback critical

    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 3
        Set                 priority_fallback error

    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 4
        Set                 priority_fallback warning

    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 5
        Set                 priority_fallback notice

    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 6
        Set                 priority_fallback info

    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals priority_fallback 7
        Set                 priority_fallback debug

    # JSONパース
    [FILTER]
        Name                parser
        Match               journal.*
        Key_Name            message
        Parser              json
        Reserve_Data        On
        Preserve_Key        On

    # JSONからlevelを抽出してログレベルとして使用
    [FILTER]
        Name                modify
        Match               journal.*
        Rename              level level_from_json

    # level_from_jsonがあればそれを使用、なければpriority_fallbackを使用
    [FILTER]
        Name                lua
        Match               journal.*
        script              ${pkgs.writeText "select-level.lua" ''
          function select_level(tag, timestamp, record)
            if record["level_from_json"] then
              record["level"] = record["level_from_json"]
              record["level_from_json"] = nil
            else
              record["level"] = record["priority_fallback"] or "info"
            end
            record["priority_fallback"] = nil
            return 1, timestamp, record
          end
        ''}
        call                select_level

    # RouterOS syslogの処理
    [FILTER]
        Name                modify
        Match               syslog
        Add                 host routeros
        Add                 log_type routeros

    # RouterOSのログレベルマッピング
    [FILTER]
        Name                lua
        Match               syslog
        script              ${luaScript}
        call                map_routeros_severity

    # 不要なフィールドを削除
    [FILTER]
        Name                modify
        Match               *
        Remove              syslog_time
        Remove              syslog_host
        Remove              ident
        Remove              pid

    # Lokiへの出力
    [OUTPUT]
        Name                loki
        Match               *
        Host                ${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain}
        Port                ${toString cfg.monitoring.loki.port}
        Labels              job=fluent-bit, host=$host
        Label_keys          $level,$service,$unit,$log_type
        Line_format         json
        Auto_kubernetes_labels Off

    # OpenSearchへの出力
    [OUTPUT]
        Name                opensearch
        Match               *
        Host                ${cfg.fluentBit.opensearchHost}
        Port                ${toString cfg.fluentBit.opensearchPort}
        Index               logs
        Type                _doc
        Logstash_Format     On
        Logstash_Prefix     logs
        Logstash_DateFormat %Y.%m.%d
        Time_Key            @timestamp
        Generate_ID         On
        Suppress_Type_Name  On
        tls                 Off
  '';
in
{
  # 設定ファイルのパスを返す
  main = fluentBitConfig;
  parsers = parsersConfig;
  lua = luaScript;
}

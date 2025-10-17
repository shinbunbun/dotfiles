/*
  Fluent Bitログ収集エージェント設定モジュール

  このモジュールは以下の機能を提供します：
  - Fluent Bit: 軽量高速なログ収集・転送エージェント
  - systemd-journalからのログ収集
  - OpenSearchへの送信（長期保存・詳細分析用）
  - Lokiへの送信（短期・リアルタイム監視用）

  使用方法:
  - nixos-desktopまたはnixosにインポートして使用
  - systemd-journalから自動的にログを収集
  - OpenSearchとLokiへ並行送信

  注意: Nginxがインストールされていない環境ではsystemd-journalのみを収集
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # config.nixから設定を読み込み
  cfg = import ../../../../shared/config.nix;

  # ホスト名を取得
  hostname = config.networking.hostName;

  # Fluent Bit設定ファイル
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

    # ログレベルの正規化（フィールド名変更）
    # PRIORITYは一時的にpriority_fallbackに保存（JSON内のlevelが優先）
    [FILTER]
        Name                modify
        Match               journal.*
        Rename              PRIORITY priority_fallback
        Rename              MESSAGE message
        Rename              SYSLOG_IDENTIFIER service
        Rename              _SYSTEMD_UNIT unit

    # priority_fallbackの数値→文字列変換（systemd PRIORITYは0-7の数値）
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

    # JSONメッセージのパース（Dockerコンテナログ用）
    # Authentikなど、JSON形式でログを出力するDockerサービスの場合、
    # MESSAGEフィールド内のJSON構造をパースし、その中のlevelフィールドを抽出する。
    # パースに成功した場合、JSON内のlevelフィールドがログレベルとして使用される。
    [FILTER]
        Name                parser
        Match               journal.*
        Key_Name            message
        Parser              json
        Reserve_Data        On
        Preserve_Key        On

    # CouchDBログレベル抽出（CouchDBサービスのみ対象）
    # CouchDBのログメッセージから [error], [warning], [notice] などのログレベルを抽出
    [FILTER]
        Name                parser
        Match               journal.*
        Key_Name            message
        Parser              couchdb_level
        Reserve_Data        On
        Preserve_Key        On
        Condition           Key_Value_Equals service docker-couchdb-obsidian-start

    # 抽出したログレベルをlevelフィールドにコピー（CouchDBのみ）
    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Value_Equals service docker-couchdb-obsidian-start
        Condition           Key_Exists extracted_level
        Copy                extracted_level level

    # extracted_levelフィールドの削除（不要になったため）
    [FILTER]
        Name                record_modifier
        Match               journal.*
        Remove_key          extracted_level

    # RouterOSログの処理
    [FILTER]
        Name                modify
        Match               syslog*
        Add                 log_type routeros

    # RouterOSログのhost名を実際の送信元（syslog_host）に設定
    [FILTER]
        Name                modify
        Match               syslog*
        Condition           Key_Exists syslog_host
        Copy                syslog_host host

    # RouterOSログトピック抽出（例: "system,info,account" から topic=system を抽出）
    # 注: 現在のRouterOSログフォーマットにはトピック情報が含まれていないため、コメントアウト
    # identフィールドがトピックの代わりとして使用可能
    #[FILTER]
    #    Name                parser
    #    Match               syslog*
    #    Key_Name            message
    #    Parser              routeros_topic
    #    Reserve_Data        On
    #    Preserve_Key        On

    # RouterOSログレベルマッピング（syslog PRIからseverity値を計算して文字列化）
    # PRI = Facility × 8 + Severity のため、Severity = PRI % 8 で抽出
    # RFC3164標準マッピング: 0=emergency, 1=alert, 2=critical, 3=error, 4=warning, 5=notice, 6=info, 7=debug
    [FILTER]
        Name    lua
        Match   syslog*
        script  ${luaScript}
        call    map_routeros_severity

    # フォールバック処理：levelが無い場合のみpriority_fallbackを使用
    # これにより、非JSON形式のログ（ログレベル抽出に失敗したCouchDBログなど）はsystemd-journalのPRIORITYを使用
    [FILTER]
        Name                modify
        Match               journal.*
        Condition           Key_Does_Not_Exist level
        Copy                priority_fallback level

    # priority_fallbackフィールドの削除（不要になったため）
    [FILTER]
        Name                record_modifier
        Match               journal.*
        Remove_key          priority_fallback

    # 不要なフィールドの削除
    [FILTER]
        Name                record_modifier
        Match               *
        Remove_key          _TRANSPORT
        Remove_key          _BOOT_ID
        Remove_key          _MACHINE_ID
        Remove_key          _HOSTNAME
        Remove_key          _GID
        Remove_key          _UID
        Remove_key          _CAP_EFFECTIVE
        Remove_key          _SELINUX_CONTEXT
        Remove_key          _AUDIT_SESSION
        Remove_key          _AUDIT_LOGINUID
        Remove_key          _SYSTEMD_CGROUP
        Remove_key          _SYSTEMD_SLICE
        Remove_key          _SYSTEMD_OWNER_UID

    # OpenSearchへの出力
    [OUTPUT]
        Name               opensearch
        Match              *
        Host               ${cfg.fluentBit.opensearchHost}
        Port               ${toString cfg.fluentBit.opensearchPort}
        Index              logs
        Type               _doc
        Logstash_Format    On
        Logstash_Prefix    logs
        Logstash_DateFormat %Y.%m.%d
        Time_Key           @timestamp
        Generate_ID        On
        Retry_Limit        5
        Buffer_Size        5MB
        HTTP_User          admin
        HTTP_Passwd        admin
        tls                Off
        tls.verify         Off
        Suppress_Type_Name On

    # Lokiへの出力（systemd-journal）
    [OUTPUT]
        Name               loki
        Match              journal.*
        Host               ${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain}
        Port               ${toString cfg.monitoring.loki.port}
        Labels             job=systemd-journal,host=${hostname}
        label_keys         $service,$unit,$level
        Line_format        json
        Auto_kubernetes_labels Off

    # Lokiへの出力（RouterOS）
    [OUTPUT]
        Name               loki
        Match              syslog*
        Host               ${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain}
        Port               ${toString cfg.monitoring.loki.port}
        Labels             job=routeros
        label_keys         $level,$ident,$host
        Line_format        json
        Auto_kubernetes_labels Off
  '';

  # RouterOSログレベルマッピング用Luaスクリプト
  # syslog PRIフィールドから severity = pri % 8 を計算し、文字列にマッピング
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

    # RouterOSトピックパーサー（現在のログフォーマットでは使用しない）
    #[PARSER]
    #    Name        routeros_topic
    #    Format      regex
    #    Regex       ^(?<topic>[^,]+),(?<severity>[^,]+),(?<facility>[^:]+):
    #    Time_Keep   On
  '';
in
{
  # Fluent Bitサービスの定義
  systemd.services.fluent-bit = {
    description = "Fluent Bit Log Processor";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      User = "fluent-bit";
      Group = "fluent-bit";
      ExecStart = "${pkgs.fluent-bit}/bin/fluent-bit -c ${fluentBitConfig}";
      Restart = "on-failure";
      RestartSec = "10s";

      # メモリ制限
      MemoryMax = "512M";
      MemoryHigh = "400M";

      # セキュリティ設定
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        "/var/lib/fluent-bit"
      ];

      # 必要な権限
      SupplementaryGroups = [ "systemd-journal" ];
      # syslogポート514（特権ポート）へのバインドを許可
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];

      # データディレクトリの作成
      StateDirectory = "fluent-bit";
      StateDirectoryMode = "0750";
    };

    preStart = ''
      # データディレクトリの確認
      mkdir -p /var/lib/fluent-bit
      chown fluent-bit:fluent-bit /var/lib/fluent-bit
    '';
  };

  # ユーザーとグループの作成
  users.users.fluent-bit = {
    isSystemUser = true;
    group = "fluent-bit";
    description = "Fluent Bit service user";
    extraGroups = [ "systemd-journal" ]; # journalへのアクセス権限
  };

  users.groups.fluent-bit = { };

  # ファイアウォール設定（メトリクスポートとsyslogポート）
  networking.firewall.allowedTCPPorts = [
    cfg.fluentBit.port # HTTP API（メトリクス）
  ];

  networking.firewall.allowedUDPPorts = [
    cfg.fluentBit.syslogPort # RouterOS syslog受信
  ];

  # 必要なパッケージ
  environment.systemPackages = with pkgs; [
    fluent-bit
  ];

  # ログローテーション設定（Fluent Bitのログ用）
  services.logrotate.settings.fluent-bit = {
    files = "/var/log/fluent-bit/*.log";
    rotate = 7;
    frequency = "daily";
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    create = "0640 fluent-bit fluent-bit";
  };
}

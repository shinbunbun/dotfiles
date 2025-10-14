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
        Rename              PRIORITY level
        Rename              MESSAGE message
        Rename              SYSLOG_IDENTIFIER service
        Rename              _SYSTEMD_UNIT unit

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

    # Lokiへの出力
    [OUTPUT]
        Name               loki
        Match              journal.*
        Host               ${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain}
        Port               ${toString cfg.monitoring.loki.port}
        Labels             job=systemd-journal,host=${hostname}
        Label_keys         level,service,unit
        Line_format        json
        Auto_kubernetes_labels Off
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
        Name        syslog
        Format      regex
        Regex       ^\<(?<pri>[0-9]+)\>(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
        Time_Key    time
        Time_Format %b %d %H:%M:%S
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

  # ファイアウォール設定（メトリクスポート）
  networking.firewall.allowedTCPPorts = [
    cfg.fluentBit.port # HTTP API（メトリクス）
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

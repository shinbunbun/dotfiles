/*
  Darwin Fluent Bit設定

  macOS用のFluent BitとmacOSログストリーミングデーモンをlaunchdで起動します。
  nixpkgsのfluent-bitはaarch64-darwinでzstdリンクが壊れているため、overrideAttrsで修正しています。

  構成:
  1. macos-log-stream: macOS Unified Logging Systemの log stream 出力をファイルに書き出す
     - 起動時に前回停止時刻からのログをキャッチアップ（欠落ゼロ設計）
     - リアルタイムストリーミングで /var/log/macos-unified.log にアペンド
  2. fluent-bit: /var/log/macos-unified.log を tail input で読み取り、Loki/OpenSearchに転送
  3. macos-log-rotate: 日次ログローテーション（7日保持）
*/
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfg = import ../../../shared/config.nix;

  # fluent-bit の aarch64-darwin zstd リンク修正
  fluent-bit = pkgs.fluent-bit.overrideAttrs (old: {
    env = (old.env or { }) // {
      NIX_LDFLAGS = "-L${pkgs.zstd.out}/lib -lzstd";
    };
  });

  # macOS用 Fluent Bit設定ファイル生成
  fluentBitConfigs = import inputs.nixos-observability-config.lib.fluentBit.darwinGenerator {
    inherit pkgs;
    inherit cfg;
    hostname = config.networking.hostName;
  };

  # ログストリーミング用ラッパースクリプト
  logStreamScript = pkgs.writeScript "macos-log-stream.sh" ''
    #!/bin/bash
    LOG_FILE="/var/log/macos-unified.log"
    STATE_FILE="/var/lib/fluent-bit/log-stream-last-ts"

    # ディレクトリ作成
    mkdir -p /var/lib/fluent-bit

    # 停止中のログをキャッチアップ
    if [ -f "$STATE_FILE" ]; then
      LAST_TS=$(cat "$STATE_FILE")
      /usr/bin/log show --start "$LAST_TS" --style ndjson \
        --predicate 'eventMessage != ""' --level info >> "$LOG_FILE" 2>/dev/null
    fi

    # 定期的に現在時刻を状態ファイルに保存（バックグラウンド）
    (
      while true; do
        /bin/date "+%Y-%m-%d %H:%M:%S%z" > "$STATE_FILE"
        sleep 10
      done
    ) &

    # リアルタイムストリーミング開始
    exec /usr/bin/log stream --style ndjson \
      --predicate 'eventMessage != ""' --level info >> "$LOG_FILE" 2>/dev/null
  '';

  # ログローテーション用スクリプト
  logRotateScript = pkgs.writeScript "macos-log-rotate.sh" ''
    #!/bin/bash
    LOG_FILE="/var/log/macos-unified.log"
    ROTATE_DIR="/var/log/macos-unified-archive"
    RETENTION_DAYS=7

    mkdir -p "$ROTATE_DIR"

    # 現在のログファイルをローテーション
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
      TIMESTAMP=$(/bin/date "+%Y%m%d-%H%M%S")
      mv "$LOG_FILE" "$ROTATE_DIR/macos-unified.$TIMESTAMP.log"
      touch "$LOG_FILE"
    fi

    # 古いアーカイブを削除
    find "$ROTATE_DIR" -name "macos-unified.*.log" -mtime +$RETENTION_DAYS -delete
  '';
in
{
  environment.systemPackages = [ fluent-bit ];

  # Fluent Bit用ストレージディレクトリ作成
  system.activationScripts.postActivation.text = ''
    echo "Setting up Fluent Bit directories..." >&2
    mkdir -p /var/lib/fluent-bit
    touch /var/log/macos-unified.log
  '';

  # 1. macOS ログストリーミングデーモン
  launchd.daemons.macos-log-stream = {
    serviceConfig = {
      Label = "com.shinbunbun.macos-log-stream";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec /bin/bash ${logStreamScript}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardErrorPath = "/var/log/macos-log-stream.error.log";
    };
  };

  # 2. Fluent Bit デーモン
  launchd.daemons.fluent-bit = {
    serviceConfig = {
      Label = "io.fluentbit.fluent-bit";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${fluent-bit}/bin/fluent-bit -c ${fluentBitConfigs.main}"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/fluent-bit.log";
      StandardErrorPath = "/var/log/fluent-bit.error.log";
    };
  };

  # 3. ログローテーション（毎日3:00に実行）
  launchd.daemons.macos-log-rotate = {
    serviceConfig = {
      Label = "com.shinbunbun.macos-log-rotate";
      ProgramArguments = [
        "/bin/bash"
        "${logRotateScript}"
      ];
      StartCalendarInterval = [
        {
          Hour = 3;
          Minute = 0;
        }
      ];
      StandardOutPath = "/var/log/macos-log-rotate.log";
      StandardErrorPath = "/var/log/macos-log-rotate.error.log";
    };
  };
}

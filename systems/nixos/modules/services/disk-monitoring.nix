/*
  ディスク SMART 監視モジュール

  機能:
  - smartd: SMART 異常を syslog/journal に通知 (Fluent Bit 経由で Loki へ転送)
  - smartctl_exporter: SMART 属性 (Reallocated_Sector, Percentage_Used, Temperature 等)
    を Prometheus 形式で公開
  - APM 無効化 udev rule: USB-SATA bridge 経由 HDD の Load_Cycle_Count 抑制 (任意)

  提供する設定:
  - services.disk-monitoring.enable
  - services.disk-monitoring.devices (list of { path, deviceType, smartdSchedule, disableAPM })
  - services.disk-monitoring.openFirewall

  使用例:
  services.disk-monitoring = {
    enable = true;
    devices = [
      {
        path = "/dev/sda";
        deviceType = "sat";
        smartdSchedule = "(S/../../7/02|L/../01/./03)";
        disableAPM = true;
      }
      { path = "/dev/nvme0"; deviceType = "nvme"; }
    ];
  };

  ポートは shared/sections/monitoring.nix の monitoring.smartctlExporter.port を使用。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.disk-monitoring;
  sharedCfg = import ../../../../shared/config.nix;
  port = sharedCfg.monitoring.smartctlExporter.port;

  deviceModule = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        example = "/dev/sda";
        description = "監視対象 block device の絶対パス。";
      };
      deviceType = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "sat";
        description = ''
          smartctl の `-d` 値。USB-SATA bridge は "sat"、NVMe は "nvme"。
          null の場合 smartd / smartctl の autodetect に任せる。
        '';
      };
      smartdSchedule = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "(S/../../7/02|L/../01/./03)";
        description = ''
          smartd の scheduled self-test パターン (`-s` 引数の中身、外側の括弧含む)。
          null の場合 self-test スケジュールは設定しない。
        '';
      };
      disableAPM = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          udev で `hdparm -B 254` を適用して APM を無効化する。
          USB-SATA HDD でデフォルト APM=128 によりヘッド退避が頻発し
          Load_Cycle_Count が過剰増加する問題を抑制するためのもの。
          path は `/dev/sdX` 形式である必要がある (KERNEL match のため)。
        '';
      };
    };
  };

  # smartd 用の options 文字列を device 設定から組み立てる
  smartdOptionsFor =
    d:
    let
      typeOpt = lib.optionalString (d.deviceType != null) "-d ${d.deviceType}";
      schedOpt = lib.optionalString (d.smartdSchedule != null) "-s ${d.smartdSchedule}";
      parts = lib.filter (s: s != "") [
        typeOpt
        "-a -o on -S on"
        schedOpt
      ];
    in
    lib.concatStringsSep " " parts;

  apmDevices = lib.filter (d: d.disableAPM) cfg.devices;
in
{
  options.services.disk-monitoring = {
    enable = lib.mkEnableOption "ディスク SMART 監視 (smartd + smartctl_exporter)";

    devices = lib.mkOption {
      type = lib.types.listOf deviceModule;
      default = [ ];
      description = "監視対象 disk のリスト。";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "smartctl_exporter のポートをファイアウォールで開放するか。";
    };
  };

  config = lib.mkIf cfg.enable {
    services.smartd = {
      enable = true;
      autodetect = false;
      devices = map (d: {
        device = d.path;
        options = smartdOptionsFor d;
      }) cfg.devices;
    };

    services.prometheus.exporters.smartctl = {
      enable = true;
      port = port;
      openFirewall = cfg.openFirewall;
      devices = map (d: d.path) cfg.devices;
    };

    # APM 無効化 udev rule (HDD の Load_Cycle_Count 抑制)。
    # USB 接続時 (add) と再接続時 (change) に hdparm -B 254 を適用。
    services.udev.extraRules = lib.optionalString (apmDevices != [ ]) (
      lib.concatMapStringsSep "\n" (
        d:
        let
          kernel = lib.removePrefix "/dev/" d.path;
        in
        ''
          ACTION=="add|change", KERNEL=="${kernel}", SUBSYSTEM=="block", \
            RUN+="${pkgs.hdparm}/bin/hdparm -B 254 /dev/%k"
        ''
      ) apmDevices
    );
  };
}

/*
  ディスク監視設定 - g3pro

  内蔵 SATA SSD (/dev/sda, TWSC TSC10N256-H6Q10S, 256GB) の SMART 監視を
  有効化します。
  - smartd: SMART 異常を syslog/journal に通知 (Fluent Bit 経由で Loki へ転送)
  - smartctl_exporter: SMART 属性 (Reallocated_Sector, Temperature 等) を
    Prometheus 形式で公開

  deviceType は省略 (smartctl の autodetect)。内蔵 SATA SSD は標準で
  SAT/ATA passthrough で認識されるため明示指定は不要。
  disableAPM は HDD の Load_Cycle_Count 抑制用途で SSD には不要。

  共通設定は systems/nixos/modules/services/disk-monitoring.nix を参照。
*/
{ ... }:
{
  services.disk-monitoring = {
    enable = true;
    devices = [
      {
        path = "/dev/sda";
      }
    ];
  };
}

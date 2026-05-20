/*
  ディスク監視設定 - homeMachine

  内蔵 NVMe SSD (/dev/nvme0, Samsung MZVLW256HEHP-000L2) の SMART 監視を有効化します。
  - smartd: SMART 異常を syslog/journal に通知 (Fluent Bit 経由で Loki へ)
  - smartctl_exporter: Percentage_Used / Available_Spare / Temperature 等の
    NVMe SMART 属性を Prometheus に公開

  共通設定は systems/nixos/modules/services/disk-monitoring.nix を参照。
*/
{ ... }:
{
  services.disk-monitoring = {
    enable = true;
    devices = [
      {
        path = "/dev/nvme0";
        deviceType = "nvme";
      }
    ];
  };
}

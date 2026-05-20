/*
  ディスク監視設定 - homeMachine

  内蔵 NVMe SSD (/dev/nvme0n1, Samsung MZVLW256HEHP-000L2) の SMART 監視を有効化します。
  - smartd: SMART 異常を syslog/journal に通知 (Fluent Bit 経由で Loki へ)
  - smartctl_exporter: Percentage_Used / Available_Spare / Temperature 等の
    NVMe SMART 属性を Prometheus に公開

  device path に namespace block device (`/dev/nvme0n1`) を使う理由:
  NVMe controller character device (`/dev/nvme0`) は 600 root:root で、
  smartctl_exporter モジュールが付与する SupplementaryGroups=disk からは
  アクセス不可。namespace block device は 660 root:disk なので OK。
  smartctl は `-d nvme` 指定で namespace device からも SMART を読める。

  共通設定は systems/nixos/modules/services/disk-monitoring.nix を参照。
*/
{ ... }:
{
  services.disk-monitoring = {
    enable = true;
    devices = [
      {
        path = "/dev/nvme0n1";
        deviceType = "nvme";
      }
    ];
  };
}

# cells/core/nixosProfiles.nix
/*
  NixOSプロファイルエントリポイント

  このモジュールはNixOS設定プロファイルを統合します：
  - base: 基本システム設定
  - networking: ネットワーク設定
  - services: サービス設定（SSH、Fail2ban、Docker）
  - security: セキュリティ設定
  - kubernetes: Kubernetesツール
  - nfs: NFSサーバー設定
  - system-tools: システム管理ツール
  - obsidian-livesync: Obsidian同期サービス
  - routeros-backup: RouterOSバックアップ
  - wireguard: WireGuard VPN設定
  - authentik: セルフホストIdP（認証プロバイダー）
  - cockpit: ウェブベースのサーバー管理インターフェース
  - ttyd: ウェブベースのターミナルエミュレータ
  - managementAccess: 管理インターフェースへのアクセス制御

  各プロファイルは独立したモジュールとして管理され、
  必要に応じて組み合わせて使用します。
*/
{ inputs, cell }:
{
  # 分割されたモジュール
  base = import ./nixosProfiles/base.nix { inherit inputs cell; };
  networking = import ./nixosProfiles/networking.nix { inherit inputs cell; };
  services = import ./nixosProfiles/services.nix { inherit inputs cell; };
  security = import ./nixosProfiles/security.nix { inherit inputs cell; };
  kubernetes = import ./nixosProfiles/kubernetes.nix { inherit inputs cell; };
  nfs = import ./nixosProfiles/nfs.nix { inherit inputs cell; };
  systemTools = import ./nixosProfiles/system-tools.nix { inherit inputs cell; };
  wireguard = import ./nixosProfiles/wireguard.nix { inherit inputs cell; };
  monitoring = import ./nixosProfiles/monitoring.nix { inherit inputs cell; };
  alertmanager = import ./nixosProfiles/alertmanager.nix { inherit inputs cell; };

  # 既存のモジュール
  obsidian-livesync = import ./nixosProfiles/obsidian-livesync.nix { inherit inputs cell; };
  routeros-backup = import ./nixosProfiles/routeros-backup.nix { inherit inputs cell; };
  authentik = import ./nixosProfiles/authentik.nix { inherit inputs cell; };

  # 管理インターフェース
  cockpit = import ./nixosProfiles/cockpit.nix { inherit inputs cell; };
  ttyd = import ./nixosProfiles/ttyd.nix { inherit inputs cell; };

  # Cloudflare統合
  unifiedCloudflareTunnel = import ./nixosProfiles/unified-cloudflare-tunnel.nix {
    inherit inputs cell;
  };
  optimise = {
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  vm =
    {
      lib,
      ...
    }:
    {
      boot.initrd.availableKernelModules = lib.mkDefault [
        "virtio_pci"
        "virtio_blk"
      ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos-root";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/nixos-boot";
        fsType = "vfat";
      };
    };

  # 互換性のためのdefaultプロファイル（全モジュールを統合）
  default =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        cell.nixosProfiles.base
        cell.nixosProfiles.networking
        cell.nixosProfiles.services
        cell.nixosProfiles.security
        cell.nixosProfiles.kubernetes
        cell.nixosProfiles.nfs
        cell.nixosProfiles.systemTools
      ];
    };
}

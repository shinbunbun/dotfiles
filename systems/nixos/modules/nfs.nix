/*
  NFSサーバー設定モジュール

  このモジュールはNFSサーバー機能を提供します：
  - NFSv4のサポート
  - /home/shinbunbunディレクトリのエクスポート
  - ホストベースのアクセス制御
  - 読み込みサイズの最適化

  config.nixのnfs設定を参照して、許可するホストを
  設定します。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = import ../../../shared/config.nix;
in
{
  # NFS server configuration
  services.nfs.server.enable = true;
  services.nfs.server.exports = lib.concatMapStringsSep "\n" (
    client: "${cfg.nfs.exportPath}  ${client.ip}(${cfg.nfs.options})"
  ) cfg.nfs.clients;

  # Open NFS port in firewall
  networking.firewall.allowedTCPPorts = [
    cfg.networking.firewall.nfsPort # NFS
  ];
}

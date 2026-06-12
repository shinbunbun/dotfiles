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
  # クライアント IP は networking.hosts を単一情報源として解決する
  # （cfg.nfs.clientHosts のホストキー → networking.hosts.<key>.ip）。
  services.nfs.server.exports = lib.concatMapStringsSep "\n" (
    host: "${cfg.nfs.exportPath}  ${cfg.networking.hosts.${host}.ip}(${cfg.nfs.options})"
  ) cfg.nfs.clientHosts;

  # Open NFS port in firewall
  networking.firewall.allowedTCPPorts = [
    cfg.networking.firewall.nfsPort # NFS
  ];
}

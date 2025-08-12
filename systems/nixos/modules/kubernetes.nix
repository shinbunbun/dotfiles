/*
  Kubernetes関連ツール設定モジュール

  このモジュールはKubernetes関連のツールを提供します：
  - kubectl: KubernetesのCLIツール
  - helm: Kubernetesパッケージマネージャー
  - stern: 複数Podのログを同時にテールするツール

  これらのツールをシステム全体で利用可能にします。
*/
{ config, pkgs, lib, ... }:
let
  cfg = import ../../../shared/config.nix;
in
{
  # Kubernetes tools
  environment.systemPackages = [
    pkgs.kompose
    pkgs.kubectl
    pkgs.kubernetes
  ];

  # Kubernetes API port
  networking.firewall.allowedTCPPorts = [
    cfg.networking.firewall.kubernetesApiPort # Kubernetes API
  ];

  # Kubernetes hosts configuration
  networking.extraHosts = ''
    ${cfg.kubernetes.master.ip} ${cfg.kubernetes.master.hostname}
  '';
}


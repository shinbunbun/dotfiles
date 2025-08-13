/*
  デスクトップ環境設定モジュール

  このモジュールはnixos-desktop用のデスクトップ環境を設定します：
  - X Window System設定
  - GNOME デスクトップ環境
  - オーディオ設定（PulseAudio）
  - OpenGL/グラフィックス設定
  - Docker仮想化
  - nix-ldダイナミックリンカー設定

  GUIアプリケーションやデスクトップ環境に必要な設定を提供します。
*/
{
  config,
  pkgs,
  lib,
  ...
}:
{
  # X Window System設定
  services.xserver = {
    enable = true;
  };

  # GNOME デスクトップ環境
  services.desktopManager.gnome = {
    enable = true;
  };

  # XDG autostart
  xdg.autostart.enable = true;

  # オーディオ設定 - PipeWireを使用（最新のLinuxではPulseAudioより推奨）
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # グラフィックス設定
  hardware.graphics.enable = true;

  # ファームウェア
  hardware.enableRedistributableFirmware = true;

  # Docker仮想化
  virtualisation.docker.enable = true;

  # nix-ld（動的リンカー設定）
  programs.nix-ld.enable = true;

  # Avahiサービス（mDNS）
  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # 最新カーネルの使用
  boot.kernelPackages = pkgs.linuxPackages_latest;
}

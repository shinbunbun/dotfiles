/*
  NixOS設定 - homeMachine

  このファイルはhomeMachineのシステム設定を定義します。
  必要なモジュールをインポートし、システム固有の設定を行います。
*/
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = import ../../../../shared/config.nix;
  homeMachineUsername = cfg.users.nixos.username;
  isVM = builtins.getEnv "NIXOS_BUILD_VM" == "1";
in
{
  imports = [
    # ハードウェア設定
    (if isVM then ../../modules/vm.nix else ./hardware.nix)

    # 基本モジュール
    ../../modules/base.nix
    ../../modules/optimise.nix
    ../../modules/networking.nix
    ../../modules/security.nix
    ../../modules/system-tools.nix
    ../../modules/wireguard.nix
    ../../modules/nfs.nix
    ../../modules/kubernetes.nix

    # サービスモジュール
    ../../modules/services/services.nix
    # ../../modules/services/monitoring.nix          # nixos-observability に移行
    ../../modules/services/alertmanager.nix
    ../../modules/services/loki.nix
    ../../modules/services/fluent-bit.nix
    ../../modules/services/authentik.nix
    ../../modules/services/cockpit.nix
    ../../modules/services/ttyd.nix
    ../../modules/services/obsidian-livesync.nix
    ../../modules/services/routeros-backup.nix
    ../../modules/services/unified-cloudflare-tunnel.nix

    # 外部モジュール
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.vscode-server.nixosModules.default
    inputs.nixos-observability.nixosModules.monitoring
  ];

  # システム設定
  networking.hostName = cfg.networking.hosts.nixos.hostname;
  system.stateVersion = cfg.system.nixosStateVersion;

  # Nixpkgs設定
  nixpkgs.config.allowUnfree = true;

  # RouterOSバックアップ設定
  services.routerosBackup = {
    enable = true;
    gitRepo = "git@github.com:shinbunbun/routeros-backups.git";
  };

  # VS Code Server設定
  services.vscode-server.enable = true;

  # SOPS設定（Grafana OAuth）
  sops = {
    secrets."grafana/oauth_client_id" = {
      sopsFile = "${inputs.self}/secrets/grafana.yaml";
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };

    secrets."grafana/oauth_client_secret" = {
      sopsFile = "${inputs.self}/secrets/grafana.yaml";
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };

    templates."grafana/oauth-env" = {
      content = ''
        GRAFANA_OAUTH_CLIENT_ID=${config.sops.placeholder."grafana/oauth_client_id"}
        GRAFANA_OAUTH_CLIENT_SECRET=${config.sops.placeholder."grafana/oauth_client_secret"}
      '';
      owner = "grafana";
      group = "grafana";
      mode = "0400";
    };
  };

  # Home Manager設定
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${homeMachineUsername} = import ../../../../home/profiles/bunbun { inherit inputs pkgs; };
  };

  # オブザーバビリティ設定（nixos-observability）
  services.observability.monitoring = {
    enable = true;

    # Prometheus設定
    prometheus = {
      enable = true;
      port = cfg.monitoring.prometheus.port;
      retentionDays = cfg.monitoring.prometheus.retentionDays;
      scrapeInterval = cfg.monitoring.prometheus.scrapeInterval;
      evaluationInterval = cfg.monitoring.prometheus.evaluationInterval;

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.monitoring.nodeExporter.port}" ];
              labels = {
                instance = "${cfg.networking.hosts.nixos.hostname}.${cfg.networking.hosts.nixos.domain}";
              };
            }
            {
              targets = [ "${cfg.networking.hosts.nixosDesktop.ip}:${toString cfg.monitoring.nodeExporter.port}" ];
              labels = {
                instance = cfg.networking.hosts.nixosDesktop.hostname;
              };
            }
          ];
        }
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = [ "localhost:${toString cfg.monitoring.prometheus.port}" ];
            }
          ];
        }
        {
          job_name = "routeros";
          static_configs = [
            {
              targets = [ cfg.routerosBackup.routerIP ];
            }
          ];
          metrics_path = "/snmp";
          params = {
            module = [ "mikrotik" ];
            auth = [ "public_v2" ];
          };
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "localhost:${toString cfg.monitoring.snmpExporter.port}";
            }
          ];
        }
      ];
    };

    # Node Exporter設定
    nodeExporter = {
      enable = true;
      port = cfg.monitoring.nodeExporter.port;
    };

    # SNMP Exporter設定
    snmpExporter = {
      enable = true;
      port = cfg.monitoring.snmpExporter.port;
      configFile = inputs.nixos-observability.assets.snmpConfig;
    };

    # Grafana設定
    grafana = {
      enable = true;
      port = cfg.monitoring.grafana.port;
      domain = cfg.monitoring.grafana.domain;

      oauth = {
        enable = true;
        name = "Authentik";
        environmentFile = config.sops.templates."grafana/oauth-env".path;
        authUrl = "${cfg.authentik.baseUrl}/application/o/authorize/";
        tokenUrl = "${cfg.authentik.baseUrl}/application/o/token/";
        apiUrl = "${cfg.authentik.baseUrl}/application/o/userinfo/";
        roleAttributePath = "contains(groups[*], 'Grafana Admins') && 'Admin' || contains(groups[*], 'Grafana Editors') && 'Editor' || 'Viewer'";
        autoLogin = true;
      };

      dashboards = {
        enable = true;
        path = inputs.nixos-observability.assets.dashboards;
      };
    };

    # データソース設定
    datasources = {
      prometheus = {
        enable = true;
        isDefault = true;
      };

      loki = {
        enable = true;
        url = "http://localhost:${toString cfg.monitoring.loki.port}";
      };
    };
  };
}

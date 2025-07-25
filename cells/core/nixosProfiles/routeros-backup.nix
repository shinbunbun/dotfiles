{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.routerosBackup;

  backupScript = pkgs.writeShellScriptBin "routeros-backup" ''
    set -euo pipefail

    # Configuration
    ROUTER_IP="${cfg.routerIP}"
    ROUTER_USER="${cfg.routerUser}"
    BACKUP_DIR="${cfg.backupDir}"
    DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="routeros_backup_''${DATE}.rsc"

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Initialize git repository if needed
    if [ ! -d "$BACKUP_DIR/.git" ]; then
        cd "$BACKUP_DIR"
        ${pkgs.git}/bin/git init
        ${pkgs.git}/bin/git remote add origin "${cfg.gitRepo}"
        ${pkgs.git}/bin/git config init.defaultBranch main
        ${pkgs.git}/bin/git checkout -b main
    fi

    cd "$BACKUP_DIR"

    # Export RouterOS configuration
    echo "Exporting RouterOS configuration from $ROUTER_IP..."
    ${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no \
        -i ${cfg.sshKeyPath} \
        "$ROUTER_USER@$ROUTER_IP" "/export file=$BACKUP_FILE" || {
        echo "Failed to export configuration"
        exit 1
    }

    # Download the backup file
    echo "Downloading backup file..."
    ${pkgs.openssh}/bin/scp -o StrictHostKeyChecking=no \
        -i ${cfg.sshKeyPath} \
        "$ROUTER_USER@$ROUTER_IP:/$BACKUP_FILE" . || {
        echo "Failed to download backup file"
        exit 1
    }

    # Remove backup file from RouterOS
    ${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no \
        -i ${cfg.sshKeyPath} \
        "$ROUTER_USER@$ROUTER_IP" "/file remove $BACKUP_FILE" || {
        echo "Failed to remove backup file from RouterOS"
        exit 1
    }

    # Create a symlink to the latest backup
    ln -sf "$BACKUP_FILE" "latest.rsc"

    # Git operations
    ${pkgs.git}/bin/git add "$BACKUP_FILE" "latest.rsc"
    ${pkgs.git}/bin/git -c user.email="routeros-backup@localhost" \
        -c user.name="RouterOS Backup Service" \
        commit -m "RouterOS backup: $DATE" || {
        echo "No changes to commit"
        exit 0
    }

    # Push to remote
    echo "Pushing to GitHub..."
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i ${cfg.sshKeyPath}"
    ${pkgs.git}/bin/git push origin main || {
        echo "Failed to push to remote repository"
        exit 1
    }

    echo "Backup completed successfully: $BACKUP_FILE"
  '';
in
{
  options.services.routerosBackup = {
    enable = mkEnableOption "RouterOS configuration backup service";

    routerIP = mkOption {
      type = types.str;
      default = "192.168.1.1";
      description = "IP address of the RouterOS device";
    };

    routerUser = mkOption {
      type = types.str;
      default = "admin";
      description = "Username for RouterOS SSH access";
    };

    backupDir = mkOption {
      type = types.path;
      default = "/var/lib/routeros-backup";
      description = "Directory to store backups";
    };

    gitRepo = mkOption {
      type = types.str;
      description = "Git repository URL for storing backups";
    };

    sshKeyPath = mkOption {
      type = types.path;
      default = "/home/bunbun/.ssh/id_ed25519";
      description = "Path to SSH private key for RouterOS access";
    };

    interval = mkOption {
      type = types.str;
      default = "daily";
      description = "Systemd timer interval (e.g., 'daily', 'weekly', '6h')";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.routeros-backup = {
      description = "RouterOS Configuration Backup";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}/bin/routeros-backup";
        User = "bunbun";
        Group = "users";
        StateDirectory = "routeros-backup";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        NoNewPrivileges = true;
        ReadWritePaths = [ cfg.backupDir ];
      };
    };

    systemd.timers.routeros-backup = {
      description = "RouterOS Configuration Backup Timer";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

  };
}

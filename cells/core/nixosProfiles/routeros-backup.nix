# cells/core/nixosProfiles/routeros-backup.nix
{ inputs, cell }:
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.routerosBackup;
  configValues = import ../config.nix;

  # SSH共通オプション
  sshCommand = "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=${
    if cfg.strictHostKeyChecking then "yes" else "no"
  } -i ${cfg.sshKeyPath}";
  scpCommand = "${pkgs.openssh}/bin/scp -o StrictHostKeyChecking=${
    if cfg.strictHostKeyChecking then "yes" else "no"
  } -i ${cfg.sshKeyPath}";

  backupScript = pkgs.writeShellScriptBin "routeros-backup" ''
    set -euo pipefail

    # Configuration
    ROUTER_IP="${cfg.routerIP}"
    ROUTER_USER="${cfg.routerUser}"
    BACKUP_DIR="${cfg.backupDir}"
    DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="routeros_backup_''${DATE}.rsc"
    MAX_RETRIES=${toString cfg.maxRetries}
    RETRY_DELAY=${toString cfg.retryDelay}

    # Helper function for error messages
    error_exit() {
        echo "ERROR: $1" >&2
        ${lib.optionalString cfg.enableNotifications ''
          # Send notification on error
          if command -v ${cfg.notificationCommand} >/dev/null 2>&1; then
              ${cfg.notificationCommand} "RouterOS Backup Failed" "$1" || true
          fi
        ''}
        exit 1
    }

    # Retry function
    retry_command() {
        local cmd="$1"
        local description="$2"
        local retries=0
        
        while [ $retries -lt $MAX_RETRIES ]; do
            if eval "$cmd"; then
                return 0
            fi
            
            retries=$((retries + 1))
            if [ $retries -lt $MAX_RETRIES ]; then
                echo "Attempt $retries failed for: $description. Retrying in $RETRY_DELAY seconds..."
                sleep $RETRY_DELAY
            fi
        done
        
        return 1
    }

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Initialize git repository if needed
    if [ ! -d "$BACKUP_DIR/.git" ]; then
        echo "Initializing Git repository..."
        cd "$BACKUP_DIR"
        ${pkgs.git}/bin/git init
        ${pkgs.git}/bin/git remote add origin "${cfg.gitRepo}"
        ${pkgs.git}/bin/git config init.defaultBranch main
        ${pkgs.git}/bin/git checkout -b main
        ${pkgs.git}/bin/git config user.name "${cfg.gitUserName}"
        ${pkgs.git}/bin/git config user.email "${cfg.gitUserEmail}"
    fi

    cd "$BACKUP_DIR"

    # Export RouterOS configuration
    echo "Exporting RouterOS configuration from $ROUTER_IP..."
    retry_command "${sshCommand} '$ROUTER_USER@$ROUTER_IP' '/export file=$BACKUP_FILE'" "RouterOS export" || error_exit "Failed to export configuration from RouterOS after $MAX_RETRIES attempts"

    # Wait for file to be written
    sleep 2

    # Download the backup file
    echo "Downloading backup file..."
    retry_command "${scpCommand} '$ROUTER_USER@$ROUTER_IP:/$BACKUP_FILE' ." "SCP download" || error_exit "Failed to download backup file after $MAX_RETRIES attempts"

    # Verify downloaded file
    if [ ! -f "$BACKUP_FILE" ]; then
        error_exit "Downloaded backup file not found"
    fi

    # Remove backup file from RouterOS
    echo "Cleaning up RouterOS..."
    ${sshCommand} "$ROUTER_USER@$ROUTER_IP" "/file remove $BACKUP_FILE" || echo "Warning: Failed to remove backup file from RouterOS"

    # Create a symlink to the latest backup
    ln -sf "$BACKUP_FILE" "latest.rsc"

    # Git operations
    echo "Committing backup to Git..."
    ${pkgs.git}/bin/git add "$BACKUP_FILE" "latest.rsc"
    ${pkgs.git}/bin/git commit -m "RouterOS backup: $DATE" || {
        echo "No changes to commit"
        exit 0
    }

    # Push to remote
    ${lib.optionalString cfg.pushToRemote ''
      echo "Pushing to remote repository..."
      export GIT_SSH_COMMAND="${sshCommand}"
      retry_command "${pkgs.git}/bin/git push origin main" "Git push" || error_exit "Failed to push to remote repository after $MAX_RETRIES attempts"
    ''}

    echo "Backup completed successfully: $BACKUP_FILE"
    ${lib.optionalString cfg.enableNotifications ''
      # Send success notification
      if command -v ${cfg.notificationCommand} >/dev/null 2>&1; then
          ${cfg.notificationCommand} "RouterOS Backup Success" "Backup completed: $BACKUP_FILE" || true
      fi
    ''}
  '';
in
{
  options.services.routerosBackup = {
    enable = mkEnableOption "RouterOS configuration backup service";

    routerIP = mkOption {
      type = types.str;
      default = configValues.routerosBackup.routerIP;
      description = "IP address of the RouterOS device";
    };

    routerUser = mkOption {
      type = types.str;
      default = configValues.routerosBackup.routerUser;
      description = "Username for RouterOS SSH access";
    };

    backupDir = mkOption {
      type = types.path;
      default = configValues.routerosBackup.backupDir;
      description = "Directory to store backups";
    };

    gitRepo = mkOption {
      type = types.str;
      description = "Git repository URL for storing backups";
    };

    sshKeyPath = mkOption {
      type = types.path;
      default = configValues.routerosBackup.sshKeyPath;
      description = "Path to SSH private key for RouterOS access";
    };

    gitUserName = mkOption {
      type = types.str;
      default = configValues.routerosBackup.git.userName;
      description = "Git user name for commits";
    };

    gitUserEmail = mkOption {
      type = types.str;
      default = configValues.routerosBackup.git.userEmail;
      description = "Git user email for commits";
    };

    strictHostKeyChecking = mkOption {
      type = types.bool;
      default = false;
      description = "Enable strict host key checking for SSH connections";
    };

    pushToRemote = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to push backups to remote Git repository";
    };

    interval = mkOption {
      type = types.str;
      default = "daily";
      description = "Systemd timer interval (e.g., 'daily', 'weekly', '6h')";
    };

    user = mkOption {
      type = types.str;
      default = configValues.users.nixos.username;
      description = "User to run the backup service as";
    };

    maxRetries = mkOption {
      type = types.int;
      default = configValues.routerosBackup.maxRetries;
      description = "Maximum number of retry attempts for failed operations";
    };

    retryDelay = mkOption {
      type = types.int;
      default = configValues.routerosBackup.retryDelay;
      description = "Delay in seconds between retry attempts";
    };

    enableNotifications = mkOption {
      type = types.bool;
      default = false;
      description = "Enable notifications for backup status";
    };

    notificationCommand = mkOption {
      type = types.str;
      default = "notify-send";
      description = "Command to use for sending notifications";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.routeros-backup = {
      description = "RouterOS Configuration Backup";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Error notification
      onFailure = lib.optional cfg.enableNotifications "routeros-backup-notify-failure@%n.service";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}/bin/routeros-backup";
        User = cfg.user;
        Group = "users";
        StateDirectory = "routeros-backup";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        NoNewPrivileges = true;
        ReadWritePaths = [ cfg.backupDir ];

        # Enhanced security
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;

        # Restart policy
        Restart = "on-failure";
        RestartSec = "5min";
        RestartPreventExitStatus = "0";
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

    # Ensure backup directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.backupDir} 0750 ${cfg.user} users -"
    ];

    # Failure notification service template
    systemd.services."routeros-backup-notify-failure@" = mkIf cfg.enableNotifications {
      description = "Notify RouterOS backup failure for %i";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "notify-failure" ''
          SERVICE_NAME="$1"
          ${cfg.notificationCommand} "RouterOS Backup Failed" "Service $SERVICE_NAME failed. Check logs: journalctl -u $SERVICE_NAME" || true
        '';
        User = cfg.user;
      };
    };
  };
}

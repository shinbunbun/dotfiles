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

    # Helper function for error messages
    error_exit() {
        echo "ERROR: $1" >&2
        exit 1
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
    ${sshCommand} "$ROUTER_USER@$ROUTER_IP" "/export file=$BACKUP_FILE" || error_exit "Failed to export configuration from RouterOS"

    # Wait for file to be written
    sleep 2

    # Download the backup file
    echo "Downloading backup file..."
    ${scpCommand} "$ROUTER_USER@$ROUTER_IP:/$BACKUP_FILE" . || error_exit "Failed to download backup file"

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
      ${pkgs.git}/bin/git push origin main || error_exit "Failed to push to remote repository"
    ''}

    echo "Backup completed successfully: $BACKUP_FILE"
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
  };

  config = mkIf cfg.enable {
    systemd.services.routeros-backup = {
      description = "RouterOS Configuration Backup";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

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
  };
}

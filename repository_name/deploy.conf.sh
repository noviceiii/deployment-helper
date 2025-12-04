#!/usr/bin/env bash
#
# deploy.conf.sh - Example (ANONYMIZED)
# Copy to /opt/deployment/repository/<your-repo>/deploy.conf.sh and edit values.
#

# Git repository URL (SSH recommended)
REPO_URL="git@github.com:owner/repo.git"

# Branch to deploy
BRANCH="main"

# Destination directory (live production path)
DEST_DIR="/var/www/example/live"

# Parent directory used for temporary clones (writable by deploy user)
TMP_PARENT="/opt/deployment/repository/example/tmp"

# Where backups will be stored
BACKUP_DIR="/opt/deployment/repository/example/backup"

# Number of backups to keep (older backups are pruned)
KEEP_BACKUPS=5

# Optional rsync excludes file (relative or absolute)
EXCLUDES_FILE="/opt/deployment/repository/example/excludes.txt"

# File/Directory ownership to set on deployed files
OWNER="www-data"
GROUP="www-data"

# Default permissions for directories and files
DIR_MODE="0755"
FILE_MODE="0644"

# Special modes to apply to specific files after deploy.
# Format: "relative/path:owner:group:mode"
SPECIAL_MODES=(
  "data/database.sqlite:www-data:www-data:0660"
  "config/prod.php:www-data:www-data:0640"
)

# Git clone depth (1 = shallow)
GIT_DEPTH=1

# Dry run default (0 = real deploy, 1 = dry run)
DRY_RUN=0

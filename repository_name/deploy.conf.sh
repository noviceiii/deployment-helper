#!/usr/bin/env bash
#
# deploy.conf.sh - Example (ANONYMIZED)
# Copy to /opt/deployment/<your-repo>/deploy.conf.sh and edit values.
#

REPO_URL="git@github.com:owner/repo.git"
BRANCH="main"
DEST_DIR="/var/www/example/live"
TMP_PARENT="/opt/deployment/<your-repo>/tmp"
BACKUP_DIR="/opt/deployment/<your-repo>/backup"
KEEP_BACKUPS=5
EXCLUDES_FILE="/opt/deployment/<your-repo>/excludes.txt"
OWNER="www-data"
GROUP="www-data"
DIR_MODE="0755"
FILE_MODE="0644"
SPECIAL_MODES=(
  "data/database.sqlite:www-data:www-data:0660"
  "config/prod.php:www-data:www-data:0640"
)
GIT_DEPTH=1
DRY_RUN=0

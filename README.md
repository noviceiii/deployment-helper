# Deployment Helper

A small, safe rsync-based deployment helper intended to be installed on a host (for example under `/opt/deployment`) and used to deploy multiple repositories using a shared `deployment.sh` script and per-repository configuration.

This document is a GitHub-flavored Markdown README and includes a detailed installation / quickstart section.

## Summary

The helper implements a simple, reproducible workflow:

1. Clone the repository (shallow) into a temporary directory.
2. Create a timestamped backup (tar.gz) of the existing live directory.
3. Sync the new files to the live directory using `rsync`, respecting an `excludes` list.
4. Set ownership and permissions consistently.
5. Keep only the last N backups (rotation).
6. Clean up temporary data.

Recommended layout (example):
```
/opt/
└── deployment
    ├── deployment.sh
    └── <your-reponame-folder>/
            ├── backup/
            ├── deploy.conf.sh
            └── tmp/
```

## Features

- Safe: creates backups before replacing live content
- Reproducible: uses shallow git clones and rsync
- Preserves production-specific files using an exclude list
- Applies consistent ownership and permission settings
- Small and portable: POSIX-ish Bash

## Quick usage examples

- Dry-run (show what would happen):
```bash
cd /opt/deployment
./deployment.sh --config /opt/deployment/repository/<your-repo>/deploy.conf.sh --dry-run
```

- Real deploy:
```bash
sudo /opt/deployment/deployment.sh --config /opt/deployment/repository/<your-repo>/deploy.conf.sh
```

- Rollback (manual): find an appropriate backup in
`/opt/deployment/repository/<your-repo>/backup/backup-YYYYMMDD-HHMMSS.tar.gz` and restore it:
```bash
sudo systemctl stop <services>          # optional
sudo rm -rf /path/to/live-dir
sudo tar -xzf /opt/deployment/repository/<your-repo>/backup/backup-YYYYMMDD-HHMMSS.tar.gz -C /path/to
sudo chown -R <owner>:<group> /path/to/live-dir
sudo systemctl start <services>
```

## Configuration (per-repo)

Each repository gets its own configuration file, typically:
`/opt/deployment/repository/<your-repo>/deploy.conf.sh`

An anonymized example:
```bash
#!/usr/bin/env bash

REPO_URL="git@github.com:owner/repo.git"
BRANCH="main"
DEST_DIR="/var/www/example/live"
TMP_PARENT="/opt/deployment/repository/example/tmp"
BACKUP_DIR="/opt/deployment/repository/example/backup"
KEEP_BACKUPS=5
EXCLUDES_FILE="/opt/deployment/repository/example/excludes.txt"
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
```

Notes:
- `REPO_URL` should be an SSH read-only deploy-key URL where possible (e.g. `git@github.com:owner/repo.git`).
- `EXCLUDES_FILE` is an rsync excludes list (see below).
- `SPECIAL_MODES` lets you set specific permissions/ownership for files that must be preserved.

## Recommended excludes

Create an `excludes.txt` with patterns relative to repo root. Example:
```
# production-specific
config.php
secrets.json
database.sqlite

# runtime / logs
log/
tmp/
.cache/

# editor / local files
.vscode/
.env
```
Always test with `--dry-run` first:
```bash
rsync --dry-run --exclude-from=/opt/deployment/repository/<your-repo>/excludes.txt <src>/ <dest>/
```

## Installation (detailed)

Two options: automated using the included `install.sh`, or manual.

Prerequisites:
- `git`, `rsync`, `tar` and standard GNU coreutils
- A deploy user (or root) that can run installs and perform deployments
- The host must be able to access the Git repository (deploy key or network access)

1) Clone the repository to `/opt/deployment` (example):
```bash
# as root or via sudo
sudo mkdir -p /opt/deployment
sudo chown $(whoami) /opt/deployment
git clone https://github.com/<your-username>/deployment.git /opt/deployment
```

2) Automated install (recommended):
```bash
# run install script (will copy scripts and create a /opt/deployment/repository/example skeleton)
sudo /opt/deployment/install.sh --prefix /opt/deployment
# dry run:
sudo /opt/deployment/install.sh --prefix /opt/deployment --dry-run
```

What `install.sh` does:
- Copies `deployment.sh` to `${PREFIX}/deployment.sh` (default `/opt/deployment/deployment.sh`) if present
- Creates `${PREFIX}/repository/example/` and places a `deploy.conf.sh.example`
- Creates `tmp/` and `backup/` skeletons under the example repository

3) Manual setup (if you prefer):
```bash
sudo cp deployment.sh /opt/deployment/deployment.sh
sudo cp install.sh /opt/deployment/install.sh
sudo chmod +x /opt/deployment/deployment.sh /opt/deployment/install.sh

sudo mkdir -p /opt/deployment/repository/<your-repo>/{tmp,backup}
sudo cp deploy.conf.sh.example /opt/deployment/repository/<your-repo>/deploy.conf.sh
# Edit the config:
sudo nano /opt/deployment/repository/<your-repo>/deploy.conf.sh
```

4) Create and register an SSH deploy key (recommended)
- On the deployment host:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -C "deploy@yourhost" -N ""
```
- Add the public key `~/.ssh/deploy_key.pub` as a repository deploy key in GitHub (read-only).
- Ensure the user performing `git clone` uses that key (SSH config or agent).

5) Test with a dry-run:
```bash
/opt/deployment/deployment.sh --config /opt/deployment/repository/<your-repo>/deploy.conf.sh --dry-run
```

6) Set up Cron or CI (optional)
- Example Cron (run as root or a deploy user):
```cron
0 4 * * 0 root /opt/deployment/deployment.sh --config /opt/deployment/repository/<your-repo>/deploy.conf.sh >> /opt/deployment/repository/<your-repo>/deploy.log 2>&1
```
Prefer CI to push artifacts to production hosts where possible.

## Security & best practices

- Never store secrets (passwords, private keys) inside `deploy.conf.sh` or the repo.
- Use repository-level deploy keys for read-only access from the deployment host.
- Run the script as a dedicated deploy user or as root depending on your need. The script sets ownership with `chown` after deploying.
- Test with `--dry-run` before production runs.

## Troubleshooting / FAQ

- Permission denied when redirecting output to a log file: the shell redirection happens as the invoking user. Use `sudo -u <user> sh -c 'cmd >> /path/log'` or place cron entries under the proper user.
- Git complains about dubious ownership: ensure the user doing `git clone` owns the tmp directory or add it to Git safe directories with `git config --global --add safe.directory <dir>`.
- No direct Git access from production: use CI to create a tarball (e.g. `git archive`) and rsync the artifact to the host instead of cloning on the host.

## License

This project is licensed under the MIT License. See `LICENSE` for details.

## Contributing

Contributions, bug reports and suggestions are welcome. Please open issues or pull requests on the repository.

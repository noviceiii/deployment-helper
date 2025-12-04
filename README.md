# Deployment helper — README

Diese README beschreibt die eingesetzte Deployment‑Struktur und zeigt, wie du das rsync‑basierte Deployment sicher benutzt.  
Du hast dich für folgende Ordnerstruktur entschieden:

/opt/
|
└── deployment
    ├── deployment.sh
    └── repository
        └── <repo-name>/
            ├── backup/
            ├── deploy.conf.sh
            └── tmp/

Kurz: Unter `/opt/deployment` liegt das Script `deployment.sh`. Für jedes Repository legst du ein eigenes Verzeichnis unter `.../repository/<repo-name>/` an. Dort sind die configs, temporäre Klone und Backups für genau dieses Repo.

Ziele dieses Setups
- Safer, reproducible deployments (backup → rsync → permissions).
- Production‑spezifische Dateien (DB, config) bleiben erhalten via excludes.
- Einfache Verwaltung mehrerer Repositories mit einer gemeinsamen deployment.sh.

Inhalt
- Konzept / Ablauf
- Verzeichnisstruktur & Beispiele
- deploy.conf.sh — wichtigste Variablen
- Excludes / Was niemals überschrieben werden sollte
- Beispiele: Dry‑run, Deploy, Rollback
- Cron / Automatisierung
- Hinweise zur Berechtigungsverwaltung

---

Konzept / Ablauf
1. Clone (shallow) des Repo in ein temporäres Verzeichnis `/opt/deployment/repository/<repo>/tmp/<random>`.
2. Erzeuge ein timestampted Backup des Live‑Verzeichnisses (tar.gz) in `/opt/deployment/repository/<repo>/backup/`.
3. Synchronisiere mit `rsync` vom tmp zum Live‑Ziel (z. B. `/var/www/...` oder `/opt/<repo>/live`) und respektiere eine `excludes`‑Liste.
4. Setze Eigentümer und Berechtigungen (Owner/Group/Dir/Files) konsistent.
5. Backup‑Rotation: nur die letzten N Backups behalten.
6. Cleanup temporäre Daten.

Verzeichnisstruktur (Beispiel)
- /opt/deployment/deployment.sh
- /opt/deployment/repository/adventor/
  - backup/                 # tar.gz Backups, rotierbar
  - deploy.conf.sh          # repo‑spezifische config für deployment.sh
  - tmp/                    # temporäre Klone (deployment.sh erzeugt/drops)

deploy.conf.sh — wichtigste Variablen
(Lege diese Datei in `/opt/deployment/repository/<repo>/deploy.conf.sh` an)

- REPO_URL
  - Git‑URL (SSH empfohlen), z. B. `git@github.com:noviceiii/adventor.git`
- BRANCH
  - Branch to deploy (z. B. `main`)
- DEST_DIR
  - Deployment destination (live path), z. B. `/var/www/www.t9t.ch/adventor` oder `/opt/adventor/live`
- TMP_PARENT
  - Parent for temp clones, e.g. `/opt/deployment/repository/adventor/tmp`
- BACKUP_DIR
  - Where backups are stored, e.g. `/opt/deployment/repository/adventor/backup`
- KEEP_BACKUPS
  - Number of backups to keep (rotation)
- EXCLUDES_FILE
  - Path to rsync excludes (patterns). See below.
- OWNER, GROUP
  - Final ownership for deployed files (e.g. `www-data`)
- DIR_MODE, FILE_MODE
  - Default permission modes (e.g. `0755`, `0644`)
- SPECIAL_MODES
  - Optional array of `"relative/path:owner:group:mode"` entries (e.g. `subscribers.db:www-data:www-data:0660`)

Beispiel (minimal)
```bash
REPO_URL="git@github.com:noviceiii/adventor.git"
BRANCH="main"
DEST_DIR="/opt/adventor/live"
TMP_PARENT="/opt/deployment/repository/adventor/tmp"
BACKUP_DIR="/opt/deployment/repository/adventor/backup"
KEEP_BACKUPS=5
EXCLUDES_FILE="/opt/deployment/repository/adventor/excludes.txt"
OWNER="www-data"
GROUP="www-data"
DIR_MODE="0755"
FILE_MODE="0644"
SPECIAL_MODES=( "subscribers.db:www-data:www-data:0660" "config.php:www-data:www-data:0640" )
```

Excludes (empfohlen)
Die Datei `excludes.txt` enthält rsync‑Muster, die nicht überschrieben werden dürfen. Beispiele:
```
# production specific
config.php
subscribers.db
daily_preview.html

# runtime/logs
log/
tmp/
.cache/

# editor / local files
.vscode/
.env
```
- Pfade sind relativ zum Repo‑Root.
- Teste `rsync --exclude-from=excludes.txt` im Dry‑run, bevor du es produktiv nutzt.

Beispiele: Dry‑run / Deploy / Rollback
- Dry run (zeigt, was passieren würde):
```bash
cd /opt/deployment
./deployment.sh --config /opt/deployment/repository/adventor/deploy.conf.sh --dry-run
```
- Real deploy:
```bash
sudo /opt/deployment/deployment.sh --config /opt/deployment/repository/adventor/deploy.conf.sh
```
(Erfordert, dass die Maschine per SSH auf das Repo zugreifen kann oder du git‑archive‑artefakte nutzt)

- Rollback (manuell): finde das gewünschte Backup in
  `/opt/deployment/repository/adventor/backup/backup-YYYYMMDD-HHMMSS.tar.gz` und entpacke es zurück:
```bash
sudo systemctl stop nginx php-fpm   # optional to avoid in-flight requests
sudo rm -rf /var/www/www.t9t.ch/adventor
sudo tar -xzf /opt/deployment/repository/adventor/backup/backup-YYYYmmdd-HHMMSS.tar.gz -C /var/www/www.t9t.ch
sudo chown -R www-data:www-data /var/www/www.t9t.ch/adventor
sudo systemctl start php-fpm nginx
```

Cron / Automatisierung
- Du kannst deployments per Cron oder CI auslösen. Beispiel Cron (run as root or deploy user):
```cron
# weekly automatic deploy (example)
0 4 * * 0 root /opt/deployment/deployment.sh --config /opt/deployment/repository/adventor/deploy.conf.sh >> /opt/deployment/repository/adventor/deploy.log 2>&1
```
- Achtung: automatische Deploys sollten nur in geprüften Szenarien laufen. Für kontrollierte Deploys empfehle ich CI/CD (GitHub Actions) die Artefakte baut und auf Production pusht.

Sicherheit & Zugriffsrechte
- Git clone via SSH: Erzeuge einen deploy key (ed25519) und registriere public key als Deploy key in GitHub (repo scope read only).
- Stelle sicher, dass `deployment.sh` auf einem Host mit sicheren SSH‑Schlüsseln ausgeführt wird.
- `deployment.sh` wird in der Regel als root oder deploy user ausgeführt; sie setzt am Ende `chown` auf die gewünschte `OWNER:GROUP`.
- Halte Secrets (Passwörter, private keys) niemals in `deploy.conf.sh` oder im Repo.

Post‑deploy hooks (optional)
- Du kannst nach dem rsync zusätzliche Schritte ausführen, z. B. Composer install, asset build, service reload. Füge diese in `deployment.sh` oder per `post_deploy.sh` Hook ein (wenn du Hooks unterstützen willst).
- Beispiel (in deploy.conf.sh):
```bash
POST_DEPLOY_CMDS=( "cd /opt/adventor/live && composer install --no-dev" "systemctl reload php8.3-fpm" )
```
und `deployment.sh` kann diese nach dem rsync ausführen.

Praktische Hinweise / Checklist
- Teste zuerst mit `--dry-run`.
- Erstelle initial die Verzeichnisse und lege `excludes.txt` an:
```bash
sudo mkdir -p /opt/deployment/repository/adventor/{tmp,backup}
sudo chown -R walther:walther /opt/deployment/repository/adventor
# create excludes file and deploy.conf.sh as described above
```
- Verifiziere, dass die Maschine GitHub per SSH erreichen kann:
```bash
sudo -u walther ssh -T git@github.com
```
- Prüfe die Backups nach dem ersten echten Deploy.

FAQ — häufige Probleme
- "Permission denied" beim Redirect `>> /path/log`: Die Shell‑Redirection wird vom aufrufenden User (z. B. walther) gemacht. Verwende `sudo -u www-data sh -c 'cmd >> /path/log'` oder führe Cron direkt als `www-data`.
- "dubious ownership" / Git meckert: Stelle sicher, dass der Benutzer, der `git clone` ausführt, Owner des TMP‑Verzeichnisses ist oder setze `git config --global --add safe.directory <dir>` für diesen User.
- Wenn Production keinen direkten Git‑Zugriff hat: nutze `git archive` in CI oder create a tarball on the build host and rsync it to /opt.

Wenn du willst, kann ich nächste Schritte liefern:
- Ein konkretes `excludes.txt` für adventor (ich kann es direkt erzeugen).
- Ein Beispiel `post_deploy.sh` Hook, das composer/npm ausführt (falls benötigt).
- Anleitung, wie du einen Deploy‑Key erstellst und in GitHub einträgst.
# deployment

# Deployment helper — README

Diese README beschreibt die eingesetzte Deployment‑Struktur und zeigt, wie du das rsync‑basierte Deployment sicher benutzt.

Projektstruktur (Beispiel)
/opt/
|
└── deployment
    ├── deployment.sh
    └── repository
        └── <your-repo>/
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
- deploy.conf.sh — wichtigste Variablen (anonymisiert)
- Excludes / Was niemals überschrieben werden sollte
- Beispiele: Dry‑run, Deploy, Rollback
- Cron / Automatisierung
- Hinweise zur Berechtigungsverwaltung
- Installation (kurzanleitung für dieses Repo)

Konzept / Ablauf
1. Clone (shallow) des Repo in ein temporäres Verzeichnis `/opt/deployment/repository/<repo>/tmp/<random>`.
2. Erzeuge ein timestampted Backup des Live‑Verzeichnisses (tar.gz) in `/opt/deployment/repository/<repo>/backup/`.
3. Synchronisiere mit `rsync` vom tmp zum Live‑Ziel (z. B. `/var/www/...` oder `/opt/<repo>/live`) und respektiere eine `excludes`‑Liste.
4. Setze Eigentümer und Berechtigungen (Owner/Group/Dir/Files) konsistent.
5. Backup‑Rotation: nur die letzten N Backups behalten.
6. Cleanup temporäre Daten.

deploy.conf.sh — wichtigste Variablen (anonymisiert)
Lege diese Datei in `/opt/deployment/repository/<your-repo>/deploy.conf.sh` an oder nutze die Beispiel‑datei aus diesem Repository.

- REPO_URL
  - Git‑URL (SSH empfohlen), z. B. `git@github.com:<owner>/<repo>.git`
- BRANCH
  - Branch to deploy (z. B. `main`)
- DEST_DIR
  - Deployment destination (live path), z. B. `/var/www/example/live`
- TMP_PARENT
  - Parent for temp clones, e.g. `/opt/deployment/repository/<your-repo>/tmp`
- BACKUP_DIR
  - Where backups are stored, e.g. `/opt/deployment/repository/<your-repo>/backup`
- KEEP_BACKUPS
  - Number of backups to keep (rotation)
- EXCLUDES_FILE
  - Path to rsync excludes (patterns). See below.
- OWNER, GROUP
  - Final ownership for deployed files (e.g. `www-data`)
- DIR_MODE, FILE_MODE
  - Default permission modes (e.g. `0755`, `0644`)
- SPECIAL_MODES
  - Optional array of `"relative/path:owner:group:mode"` entries

Anonymisiertes Beispiel (voll dokumentiert) findest du in deploy.conf.sh.example in diesem Repo.

Excludes (empfohlen)
Die Datei `excludes.txt` enthält rsync‑Muster, die nicht überschrieben werden dürfen. Beispiele:
```
# production specific
config.php
secrets.json
database.sqlite

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
./deployment.sh --config /opt/deployment/repository/<your-repo>/deploy.conf.sh --dry-run
```
- Real deploy:
```bash
sudo /opt/deployment/deployment.sh --config /opt/deployment/repository/<your-repo>/deploy.conf.sh
```

- Rollback (manuell): finde das gewünschte Backup in
  `/opt/deployment/repository/<your-repo>/backup/backup-YYYYMMDD-HHMMSS.tar.gz` und entpacke es zurück:
```bash
sudo systemctl stop <services>   # optional
sudo rm -rf /path/to/live-dir
sudo tar -xzf /opt/deployment/repository/<your-repo>/backup/backup-YYYYMMDD-HHMMSS.tar.gz -C /path/to
sudo chown -R <owner>:<group> /path/to/live-dir
sudo systemctl start <services>
```

Cron / Automatisierung
- Du kannst deployments per Cron oder CI auslösen. Beispiel Cron (run as root or deploy user):
```cron
# weekly automatic deploy (example)
0 4 * * 0 root /opt/deployment/deployment.sh --config /opt/deployment/repository/<your-repo>/deploy.conf.sh >> /opt/deployment/repository/<your-repo>/deploy.log 2>&1
```
- Achtung: automatische Deploys sollten nur in geprüften Szenarien laufen.

Sicherheit & Zugriffsrechte
- Git clone via SSH: Erzeuge einen deploy key (ed25519) und registriere public key als Deploy key in GitHub (nur read‑access).
- Halte Secrets niemals in `deploy.conf.sh` oder im Repo.

Installation (kurz)
1. Clone dieses Repository oder kopiere die Dateien nach /opt/deployment:
```bash
# als root oder mit sudo
sudo mkdir -p /opt/deployment
sudo chown $(whoami) /opt/deployment
git clone https://github.com/<your-username>/deployment.git /opt/deployment
```
oder alternativ:
```bash
# kopiere nur die relevanten Dateien
sudo cp deployment.sh /opt/deployment/
sudo cp install.sh /opt/deployment/
```

2. Beispiel‑install (empfohlen): benutze das mitgelieferte install.sh, um Skeletons und Beispiel‑config zu erzeugen:
```bash
sudo /opt/deployment/install.sh --prefix /opt/deployment
# oder in DRY RUN mode:
# /opt/deployment/install.sh --prefix /opt/deployment --dry-run
```

3. Lege für jedes Projekt ein Repo‑Verzeichnis an und passe die Beispiel‑config an:
```bash
sudo mkdir -p /opt/deployment/repository/<your-repo>/{tmp,backup}
sudo cp /opt/deployment/repository/example/deploy.conf.sh.example /opt/deployment/repository/<your-repo>/deploy.conf.sh
# editieren:
sudo nano /opt/deployment/repository/<your-repo>/deploy.conf.sh
```

4. Teste zunächst mit --dry-run.

Weitere Hilfe
- Wenn du willst, anonymisiere ich zusätzlich die README‑Abschnitte oder erzeuge eine vollständige deploy.conf.sh.example basierend auf deinem Projekt‑Layout.

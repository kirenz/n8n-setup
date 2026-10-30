#!/usr/bin/env bash
# ============================================================================
# Backup-Skript für die n8n-Hetzner-Instanz.
#
# Sichert in /opt/n8n/backups einen zusammengehörigen Satz:
#   - Postgres-Dump (alle Workflows, Credentials, Executions)
#   - n8n-Daten-Volume als Tarball (Binärdaten, Einstellungen)
#   - .env (enthält den N8N_ENCRYPTION_KEY und die Image-Tags; ohne diesen
#     Key sind alle verschlüsselten Credentials wertlos)
#
# Konsistenz: n8n wird für die Dauer der Sicherung kurz angehalten, damit
# Datenbank und Daten-Volume denselben Stand haben. n8n startet danach
# wieder, auch wenn ein Sicherungsschritt fehlschlägt.
#
# Rotation: nur die jüngsten 7 Sätze bleiben erhalten.
#
# WICHTIG: Dieses Backup liegt AUF DEMSELBEN SERVER. Bei Server-Verlust
# ist es weg. Den backups/-Ordner regelmäßig per `scp` auf einen anderen
# Rechner kopieren (siehe betrieb/backups.qmd).
# ============================================================================

set -euo pipefail

# Backup-Dateien enthalten Workflow-Daten und den Encryption-Key: nur für
# root lesbar anlegen.
umask 077

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${REPO_DIR}/backups"
TIMESTAMP="$(date +%Y-%m-%d-%H%M)"
RETAIN=7

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"
cd "${REPO_DIR}"

echo "[backup] $(date -Is) – Start (${TIMESTAMP})"

# ---- 1. n8n anhalten ----
# Ab hier startet der trap n8n in jedem Fall wieder, auch bei Fehlern.
echo "[backup] n8n kurz anhalten"
trap 'echo "[backup] n8n wieder starten"; docker compose start n8n >/dev/null' EXIT
docker compose stop n8n

# ---- 2. Postgres-Dump ----
# pg_dump läuft im Postgres-Container, das Ergebnis kommt per Pipe auf den
# Host. So braucht es keinen Postgres-Client auf dem Host.
echo "[backup] Postgres-Dump"
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
  | gzip > "${BACKUP_DIR}/postgres-${TIMESTAMP}.sql.gz"

# ---- 3. n8n-Daten-Volume ----
# Ein Einmal-Container mit denselben Volumes liest das Verzeichnis, während
# n8n gestoppt ist. Das n8n-Image bringt tar mit.
echo "[backup] n8n-Daten"
docker compose run --rm --no-deps -T --entrypoint sh n8n -c 'cd /home/node && tar cf - .n8n' \
  | gzip > "${BACKUP_DIR}/n8n-data-${TIMESTAMP}.tar.gz"

# ---- 4. .env (enthält den Encryption-Key) ----
# Eigene Kopie pro Backup-Satz, damit Recovery autark möglich ist.
echo "[backup] .env"
cp "${REPO_DIR}/.env" "${BACKUP_DIR}/env-${TIMESTAMP}.backup"

# ---- 5. Rotation ----
# Älteste Sätze entfernen, nur die letzten ${RETAIN} behalten.
# Es gibt drei Datei-Familien (postgres-*, n8n-data-*, env-*), jede wird
# separat rotiert.
prune() {
  local pattern="$1"
  ls -1t "${BACKUP_DIR}"/${pattern} 2>/dev/null | tail -n +$((RETAIN + 1)) | xargs -r rm -f
}
prune "postgres-*.sql.gz"
prune "n8n-data-*.tar.gz"
prune "env-*.backup"

echo "[backup] $(date -Is) – Fertig"
ls -lh "${BACKUP_DIR}"

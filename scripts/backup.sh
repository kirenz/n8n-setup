#!/usr/bin/env bash
# ============================================================================
# Backup-Skript für die n8n-Hetzner-Instanz.
#
# Sichert in /opt/n8n/backups:
#   - Postgres-Dump (alle Workflows, Credentials, Executions)
#   - n8n-Daten-Volume als Tarball (User-Settings, Custom-Nodes, Logs)
#   - .env (enthält den N8N_ENCRYPTION_KEY – ohne diesen Key sind alle
#     verschlüsselten Credentials wertlos)
#
# Rotation: nur die jüngsten 7 Sätze bleiben erhalten.
#
# WICHTIG: Dieses Backup liegt AUF DEMSELBEN SERVER. Bei Server-Verlust
# ist es weg. Wer Workflows behalten möchte, muss vor dem Server-Delete
# den backups/-Ordner per `scp` lokal sichern (siehe docs/server-loeschen.md).
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${REPO_DIR}/backups"
TIMESTAMP="$(date +%Y-%m-%d-%H%M)"
RETAIN=7

mkdir -p "${BACKUP_DIR}"
cd "${REPO_DIR}"

echo "[backup] $(date -Is) – Start (${TIMESTAMP})"

# ---- 1. Postgres-Dump ----
# pg_dump läuft im Postgres-Container, das Ergebnis kommt per Pipe auf den
# Host. So brauchen wir keinen Postgres-Client auf dem Host.
echo "[backup] Postgres-Dump"
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' \
  | gzip > "${BACKUP_DIR}/postgres-${TIMESTAMP}.sql.gz"

# ---- 2. n8n-Daten-Volume ----
# Tar aus dem laufenden n8n-Container heraus. Alpine bringt busybox-tar mit.
echo "[backup] n8n-Daten"
docker compose exec -T n8n sh -c 'cd /home/node && tar cf - .n8n' \
  | gzip > "${BACKUP_DIR}/n8n-data-${TIMESTAMP}.tar.gz"

# ---- 3. .env (enthält den Encryption-Key) ----
# Eigene Kopie pro Backup-Satz, damit Recovery autark möglich ist.
echo "[backup] .env"
cp "${REPO_DIR}/.env" "${BACKUP_DIR}/env-${TIMESTAMP}.backup"
chmod 600 "${BACKUP_DIR}/env-${TIMESTAMP}.backup"

# ---- 4. Rotation ----
# Älteste Sätze entfernen, nur die letzten ${RETAIN} behalten.
# Es gibt drei Datei-Familien (postgres-*, n8n-data-*, env-*) – jede wird
# separat rotiert.
prune() {
  local pattern="$1"
  ls -1t ${BACKUP_DIR}/${pattern} 2>/dev/null | tail -n +$((RETAIN + 1)) | xargs -r rm -f
}
prune "postgres-*.sql.gz"
prune "n8n-data-*.tar.gz"
prune "env-*.backup"

echo "[backup] $(date -Is) – Fertig"
ls -lh "${BACKUP_DIR}"

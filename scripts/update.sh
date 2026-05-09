#!/usr/bin/env bash
# ============================================================================
# Update-Skript für die n8n-Hetzner-Instanz.
#
# Ablauf:
#   1. Pre-Backup über scripts/backup.sh
#   2. Aktuelle Image-Tags aus .env ziehen
#   3. docker compose pull && docker compose up -d
#
# Updaten = den gewünschten Tag in .env ändern (z. B. N8N_IMAGE_TAG=1.124.0)
# und dieses Skript laufen lassen. Damit ist das Update reproduzierbar
# und der gewünschte Stand bleibt im Repo dokumentiert.
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

echo "[update] $(date -Is) – Start"

# 1. Pre-Backup. Bei Fehlern hier wird das Update abgebrochen.
echo "[update] Pre-Backup"
"${REPO_DIR}/scripts/backup.sh"

# 2. Aktuelle Tags aus .env anzeigen, damit nachvollziehbar bleibt, auf
#    welche Versionen geupdatet wurde.
echo "[update] Tags aus .env"
grep -E "^(N8N|POSTGRES|CADDY)_IMAGE_TAG=" .env

# 3. Pull + Up.
echo "[update] docker compose pull"
docker compose pull

echo "[update] docker compose up -d"
docker compose up -d

# 4. Status prüfen.
sleep 5
docker compose ps

echo "[update] $(date -Is) – Fertig"

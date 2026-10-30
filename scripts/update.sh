#!/usr/bin/env bash
# ============================================================================
# Update-Skript für die n8n-Hetzner-Instanz.
#
# Verwendung:
#   scripts/update.sh <tag>                 n8n, etwa: scripts/update.sh 2.46.1
#   scripts/update.sh n8n <tag>             dasselbe, ausdrücklich
#   scripts/update.sh caddy <tag>           etwa: scripts/update.sh caddy 2.11.8-alpine
#   scripts/update.sh postgres <tag>        nur innerhalb der Hauptversion,
#                                           etwa: 18.4-alpine3.24 -> 18.5-alpine3.24
#   scripts/update.sh                       zieht die Tags, die bereits in .env stehen
#
# Ablauf:
#   1. Tag prüfen (Form, bei Postgres gleiche Hauptversion)
#   2. Backup über scripts/backup.sh, solange .env noch die bisherigen
#      Versionen nennt. Dieser Satz ist der Rückweg (scripts/restore.sh).
#   3. Tag in .env setzen, docker compose pull. Scheitert der Pull, wird die
#      bisherige .env wiederhergestellt.
#   4. docker compose up -d, warten bis n8n über HTTPS als bereit meldet
#
# Rückweg: Den alten Tag wieder einzutragen genügt nicht, wenn n8n die
# Datenbank beim Start migriert hat. Dann den Satz aus Schritt 2 mit
# scripts/restore.sh /opt/n8n/backups zurückspielen.
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

# ---- Argumente auswerten ----
COMPONENT=""
NEW_TAG=""
case "$#" in
  0) ;;
  1) COMPONENT="n8n"; NEW_TAG="$1" ;;
  2) COMPONENT="$1"; NEW_TAG="$2" ;;
  *) echo "Verwendung: $0 [n8n|caddy|postgres] <tag>" >&2; exit 1 ;;
esac

# ---- 1. Tag vor allem anderen prüfen ----
# Ein Tippfehler (etwa ein Leerzeichen) soll weder Backup noch Neustart
# auslösen.
if [ -n "${COMPONENT}" ]; then
  case "${COMPONENT}" in
    n8n)      VAR="N8N_IMAGE_TAG";      PATTERN='^[0-9]+\.[0-9]+\.[0-9]+$';            EXAMPLE="2.46.1" ;;
    caddy)    VAR="CADDY_IMAGE_TAG";    PATTERN='^[0-9]+\.[0-9]+\.[0-9]+-alpine$';     EXAMPLE="2.11.8-alpine" ;;
    postgres) VAR="POSTGRES_IMAGE_TAG"; PATTERN='^[0-9]+\.[0-9]+-alpine[0-9.]+$';      EXAMPLE="18.5-alpine3.24" ;;
    *) echo "[update] FEHLER: unbekannte Komponente '${COMPONENT}' (n8n, caddy, postgres)" >&2; exit 1 ;;
  esac
  if ! [[ "${NEW_TAG}" =~ ${PATTERN} ]]; then
    echo "[update] FEHLER: '${NEW_TAG}' ist kein Tag der Form ${EXAMPLE}" >&2
    exit 1
  fi
  if [ "${COMPONENT}" = "postgres" ]; then
    OLD_MAJOR="$(grep -E '^POSTGRES_IMAGE_TAG=' .env | cut -d= -f2 | cut -d. -f1)"
    NEW_MAJOR="${NEW_TAG%%.*}"
    if [ "${OLD_MAJOR}" != "${NEW_MAJOR}" ]; then
      echo "[update] FEHLER: Postgres-Hauptversion ${OLD_MAJOR} -> ${NEW_MAJOR} braucht Dump und Restore, kein Tag-Wechsel" >&2
      exit 1
    fi
  fi
fi

echo "[update] $(date -Is) – Start"
echo "[update] Bisherige Tags:"
grep -E "^(N8N|POSTGRES|CADDY)_IMAGE_TAG=" .env

# ---- 2. Backup mit dem bisherigen Stand ----
# Bei Fehlern bricht das Update hier ab.
echo "[update] Backup vor dem Update"
"${REPO_DIR}/scripts/backup.sh"

# ---- 3. Tag setzen und Images laden ----
cp .env .env.vor-update
if [ -n "${COMPONENT}" ]; then
  sed -i "s|^${VAR}=.*|${VAR}=${NEW_TAG}|" .env
  echo "[update] ${VAR}=${NEW_TAG}"
fi

echo "[update] docker compose pull"
if ! docker compose pull; then
  cp .env.vor-update .env
  echo "[update] FEHLER: Pull fehlgeschlagen, bisherige .env wiederhergestellt." >&2
  echo "[update] Schreibweise des Tags prüfen. Es wurde nichts neu gestartet." >&2
  exit 1
fi

# ---- 4. Neu starten und Bereitschaft prüfen ----
# Nach einem n8n-Update kann die Datenbank-Migration einige Minuten dauern.
echo "[update] docker compose up -d"
docker compose up -d

DOMAIN="$(grep -E '^DOMAIN=' .env | cut -d= -f2-)"
echo "[update] Warte auf https://${DOMAIN}/healthz/readiness"
for _ in $(seq 1 60); do
  if curl -fsS --max-time 5 "https://${DOMAIN}/healthz/readiness" >/dev/null 2>&1; then
    docker compose ps
    echo "[update] $(date -Is) – Fertig, n8n antwortet."
    exit 0
  fi
  sleep 10
done

docker compose ps
echo "[update] FEHLER: n8n antwortet nach 10 Minuten nicht." >&2
echo "[update] Logs: docker compose logs n8n --tail 50" >&2
echo "[update] Rückweg: scripts/restore.sh ${REPO_DIR}/backups" >&2
exit 1

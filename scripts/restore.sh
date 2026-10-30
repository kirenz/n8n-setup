#!/usr/bin/env bash
# ============================================================================
# Restore-Skript für die n8n-Hetzner-Instanz.
#
# Spielt den jüngsten Backup-Satz aus einem Verzeichnis zurück:
#   postgres-<zeit>.sql.gz, n8n-data-<zeit>.tar.gz, env-<zeit>.backup
#
# Verwendung:
#   scripts/restore.sh <verzeichnis>     etwa /root/restore oder /opt/n8n/backups
#
# Zwei Fälle:
#   - Umzug auf einen neuen Server: Die alte .env (mit altem Encryption-Key,
#     alten Image-Tags und altem Datenbank-Passwort) wird übernommen, nur die
#     Domain wird auf die des neuen Servers umgestellt.
#   - Rückweg nach einem missglückten Update: Der Satz vor dem Update
#     enthält die alte Version samt passender Datenbank.
#
# ACHTUNG: Das Skript löscht die aktuelle Datenbank und das n8n-Daten-Volume
# dieses Servers und ersetzt sie durch den Backup-Stand.
# ============================================================================

set -euo pipefail
umask 077

SRC_DIR="${1:-}"
if [ -z "${SRC_DIR}" ] || [ ! -d "${SRC_DIR}" ]; then
  echo "Verwendung: $0 <verzeichnis-mit-backup-dateien>" >&2
  exit 1
fi

# Relativen Pfad vor dem Verzeichniswechsel absolut machen.
SRC_DIR="$(cd "${SRC_DIR}" && pwd)"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

# ---- 1. Jüngsten vollständigen Satz finden ----
DUMP="$(ls -1t "${SRC_DIR}"/postgres-*.sql.gz 2>/dev/null | head -n 1 || true)"
if [ -z "${DUMP}" ]; then
  echo "[restore] FEHLER: kein postgres-*.sql.gz in ${SRC_DIR}" >&2
  exit 1
fi
TS="$(basename "${DUMP}" .sql.gz)"
TS="${TS#postgres-}"
DATA="${SRC_DIR}/n8n-data-${TS}.tar.gz"
ENV_BACKUP="${SRC_DIR}/env-${TS}.backup"
for f in "${DATA}" "${ENV_BACKUP}"; do
  if [ ! -f "${f}" ]; then
    echo "[restore] FEHLER: ${f} fehlt, Satz ${TS} ist unvollständig" >&2
    exit 1
  fi
done

# ---- 2. Domain dieses Servers merken ----
NEW_DOMAIN="$(grep -E '^DOMAIN=' .env | cut -d= -f2-)"
OLD_DOMAIN="$(grep -E '^DOMAIN=' "${ENV_BACKUP}" | cut -d= -f2-)"

echo "[restore] Backup-Satz:   ${TS}"
echo "[restore] Alte Domain:   ${OLD_DOMAIN}"
echo "[restore] Diese Domain:  ${NEW_DOMAIN}"
echo
echo "Datenbank und n8n-Daten dieses Servers werden ersetzt."
read -r -p "Zum Fortfahren RESTORE eintippen: " CONFIRM
if [ "${CONFIRM}" != "RESTORE" ]; then
  echo "[restore] Abgebrochen."
  exit 1
fi

# ---- 3. Stack stoppen, Datenbank- und Daten-Volume leeren ----
# Postgres legt beim ersten Start eine leere Datenbank mit dem Passwort aus
# der .env an. Deshalb wird das Volume entfernt und mit der alten .env neu
# angelegt. caddy_data (Zertifikate) bleibt erhalten.
echo "[restore] Stack stoppen"
docker compose down
PROJECT="$(docker compose config | sed -n 's/^name: //p')"
docker volume rm -f "${PROJECT}_postgres_data" "${PROJECT}_n8n_data" >/dev/null

# ---- 4. Alte .env übernehmen, Domain anpassen ----
cp .env ".env.vor-restore-$(date +%Y-%m-%d-%H%M)"
cp "${ENV_BACKUP}" .env
if [ -n "${NEW_DOMAIN}" ] && [ "${OLD_DOMAIN}" != "${NEW_DOMAIN}" ]; then
  echo "[restore] Domain auf ${NEW_DOMAIN} umstellen (DOMAIN, N8N_HOST, WEBHOOK_URL)"
  # Nur die drei Zeilen setzen, keine Suche-und-Ersetze über die ganze Datei.
  sed -i \
    -e "s|^DOMAIN=.*|DOMAIN=${NEW_DOMAIN}|" \
    -e "s|^N8N_HOST=.*|N8N_HOST=${NEW_DOMAIN}|" \
    -e "s|^WEBHOOK_URL=.*|WEBHOOK_URL=https://${NEW_DOMAIN}/|" \
    .env
fi
chmod 600 .env

# ---- 5. Postgres starten und Dump einspielen ----
echo "[restore] Postgres starten"
docker compose up -d postgres
for _ in $(seq 1 30); do
  if docker compose exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "[restore] Dump einspielen"
gunzip -c "${DUMP}" \
  | docker compose exec -T postgres sh -c 'psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null

# ---- 6. n8n-Daten-Volume zurückspielen ----
# Der Einmal-Container läuft als Nutzer node, die Dateien gehören damit
# demselben Nutzer wie im laufenden n8n.
echo "[restore] n8n-Daten zurückspielen"
gunzip -c "${DATA}" \
  | docker compose run --rm --no-deps -T --entrypoint sh n8n -c 'cd /home/node && tar xf -'

# ---- 7. Alles starten und Erreichbarkeit prüfen ----
echo "[restore] Stack starten"
docker compose up -d
DOMAIN="$(grep -E '^DOMAIN=' .env | cut -d= -f2-)"
for _ in $(seq 1 30); do
  if curl -fsS --max-time 5 "https://${DOMAIN}/healthz/readiness" >/dev/null 2>&1; then
    echo "[restore] Fertig: https://${DOMAIN} antwortet."
    echo "[restore] Jetzt anmelden und Workflows sowie Credentials prüfen."
    exit 0
  fi
  sleep 10
done

echo "[restore] WARNUNG: https://${DOMAIN} antwortet noch nicht." >&2
echo "[restore] Logs prüfen: docker compose logs n8n --tail 50" >&2
exit 1

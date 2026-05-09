# Server nach Kursende löschen

Pflicht-Schritt für jede Studierende und jeden Studierenden. Nicht-genutzte
Server kosten Geld und vergrößern die Angriffsfläche unnötig.

## Vorher: Sichern, was bleiben soll

### A) Workflows als JSON exportieren (empfohlen)

Im n8n-UI:

1. Im Workflow-Editor oben rechts auf das Drei-Punkte-Menü klicken
2. „Download" → JSON-Datei wird heruntergeladen
3. Diese Datei lokal sicher ablegen

So gesichert sind die Workflows portierbar; sie können später in eine
neue n8n-Instanz importiert werden. Credentials werden dabei
**nicht mitgegeben** (siehe nächster Schritt).

### B) Backups lokal sichern (für Voll-Restore)

Wer auch Credentials behalten will, braucht das Postgres-Backup *und* die
`.env`-Datei mit dem Encryption-Key.

```bash
ssh root@<server-ip>
/opt/n8n/scripts/backup.sh
exit

# Lokal:
scp -r root@<server-ip>:/opt/n8n/backups ./n8n-backup-$(date +%F)
```

Im Verzeichnis `n8n-backup-YYYY-MM-DD` liegen jetzt:

- `postgres-…sql.gz` – Datenbank-Dump
- `n8n-data-…tar.gz` – n8n-Daten-Volume
- `env-…backup` – Konfiguration mit `N8N_ENCRYPTION_KEY`

> **Ohne den Encryption-Key sind die im Postgres-Dump enthaltenen
> Credentials wertlos.** Die `env-…backup`-Datei muss zusammen mit dem
> Postgres-Dump aufbewahrt werden – idealerweise an einem sicheren Ort
> (verschlüsselter Container, Passwort-Manager-Anhang).

## Server in der Hetzner-Console löschen

In der Hetzner-Console:

1. **Server → Server auswählen → Aktionen → Löschen**
2. Server-Namen zur Bestätigung eintippen
3. Auf „Löschen" klicken

Das Löschen ist **unwiderruflich**. Der Server, alle Volumes und alle
Daten werden entfernt; auf Hetzner-Seite bleibt nichts zurück.

> *(Screenshot-Platzhalter: docs/screenshots/05-server-delete.png)*

## Aufräumen

- **Hetzner Cloud Firewall** kann gelöscht werden, wenn keine weiteren
  Server sie nutzen (Firewalls → Auswählen → Löschen).
- **SSH-Schlüssel** müssen nicht entfernt werden, sind kein Datenleck.
- **Hetzner-Account selbst**: nur löschen, wenn niemand mehr Hetzner
  nutzen will. Account löschen entfernt auch laufende Rechnungen und
  Zugang zu vergangenen Belegen.

## Restore in eine neue Instanz (falls später nötig)

Auf einem frischen, mit dieser Anleitung aufgesetzten Server:

```bash
ssh root@<neue-ip>

# Stack stoppen
cd /opt/n8n
docker compose down

# Encryption-Key aus dem alten Backup einspielen
cp /pfad/zur/env-YYYY-…backup /opt/n8n/.env
# DOMAIN auf die neue Server-IP anpassen!
nano /opt/n8n/.env

# Postgres-Volume vorbereiten
docker compose up -d postgres
sleep 10

# Dump einspielen
zcat /pfad/zum/postgres-YYYY-…sql.gz \
  | docker compose exec -T postgres psql -U n8n n8n

# n8n-Daten zurückspielen
docker compose up -d n8n
docker compose exec -T n8n sh -c 'cd /home/node && tar xzf -' \
  < /pfad/zum/n8n-data-YYYY-…tar.gz

# Caddy starten
docker compose up -d caddy
```

Workflows und Credentials sind nun in der neuen Instanz verfügbar. Externe
OAuth-Verbindungen müssen je nach Anbieter neu autorisiert werden, weil
die Callback-URL sich ändert.

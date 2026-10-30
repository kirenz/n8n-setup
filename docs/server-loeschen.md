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
scp -r root@<server-ip>:/opt/n8n/backups ./n8n-backup-<datum>
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
# Lokal: gesicherten Ordner auf den neuen Server kopieren
scp -r ./n8n-backup-<datum> root@<neue-ip>:/root/restore

# Auf dem neuen Server: jüngsten Satz zurückspielen
ssh root@<neue-ip>
/opt/n8n/scripts/restore.sh /root/restore
```

Das Skript übernimmt die alte `.env` (Encryption-Key, Image-Tags,
Datenbank-Passwort), setzt `DOMAIN`, `N8N_HOST` und `WEBHOOK_URL` auf die
Domain des neuen Servers, legt Postgres- und n8n-Volume neu an, spielt
Dump und Daten-Tarball bei gestopptem n8n ein und wartet auf
`/healthz/readiness`.

Workflows und Credentials sind nun in der neuen Instanz verfügbar. Externe
OAuth-Verbindungen müssen je nach Anbieter neu autorisiert werden, weil
die Callback-URL sich ändert.

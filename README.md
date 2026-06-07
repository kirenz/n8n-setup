# n8n auf Hetzner Cloud – Kurs-Setup

DSGVO-konformer, produktionsähnlicher n8n-Stack auf Hetzner Cloud, fertig in
unter zehn Minuten. Begleitmaterial zur Lehre an der HdM Stuttgart und zu
Trainings über kirenz.de.


Der Stack besteht aus n8n + Postgres + Caddy als Reverse Proxy mit
automatischem TLS. Provisioning per Cloud-Init, alle Container-Images
versionsgepinnt.

---

## Was wird hier gebaut?

```
Browser ──HTTPS──> Caddy ──HTTP──> n8n ──SQL──> Postgres
                  (80/443)        (5678)       (5432)
                  Auto-TLS
```

Details: [docs/architektur.md](docs/architektur.md)

## Voraussetzungen

- **Hetzner-Cloud-Account** (Registrierung unter
  [console.hetzner.cloud](https://console.hetzner.cloud))
- **SSH-Schlüssel**, in der Hetzner-Console hinterlegt
- **Budget:** ca. 4 € (CPX11) bis 7 € (CPX21) pro Monat. Server lässt
  sich jederzeit löschen.
- Etwa 30 Minuten Zeit für das erste Setup.

---

## Schritt-für-Schritt-Anleitung

### 1. Hetzner Cloud Firewall anlegen

In der Hetzner-Console zu **Firewalls → Firewall erstellen**:

- Name: `n8n-firewall`
- Eingehende Regeln: nur SSH (22), HTTP (80), HTTPS (443) von überall
- Ausgehende Regeln: alle erlauben

*Diese Firewall arbeitet auf Provider-Ebene und blockiert Traffic, bevor er
den Server überhaupt erreicht. UFW im Server bleibt als zweite Schicht
zusätzlich aktiv.*

> *(Screenshot-Platzhalter: docs/screenshots/01-firewall.png)*

### 2. Server erstellen

In der Hetzner-Console zu **Server → Server erstellen**:

| Einstellung   | Wert                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------ |
| Standort      | Nürnberg oder Falkenstein                                                                              |
| Image         | Ubuntu 24.04                                                                                            |
| Server-Typ    | **CPX11** (2 vCPU, 2 GB RAM, ~4 €/Monat) – Minimum für Kurs<br>oder **CPX21** (4 GB RAM, ~7 €) – empfohlen, wenn AI-Nodes geplant sind |
| SSH-Key       | hinterlegten Key auswählen                                                                              |
| Firewall      | `n8n-firewall` aus Schritt 1                                                                            |
| Cloud-Config  | Inhalt der Datei [`cloud-init.yaml`](cloud-init.yaml) komplett einfügen                                  |
| Name          | beliebig, z. B. `n8n-kurs`                                                                              |

> *(Screenshot-Platzhalter: docs/screenshots/02-server-config.png)*

Server starten. Provisioning dauert 5–8 Minuten – Docker wird installiert,
das Repo wird geklont, Secrets werden generiert, Container starten.

### 3. URL ermitteln

Sobald der Server läuft, einmal per SSH einloggen. Die Begrüßungsnachricht
zeigt direkt die URL:

```bash
ssh root@<server-ip>
```

Beispiel-Ausgabe:

```
n8n läuft. Aufrufen unter:
  https://1-2-3-4.sslip.io
```

> *(Screenshot-Platzhalter: docs/screenshots/03-motd.png)*

Falls die Begrüßung noch nicht da ist: Provisioning läuft noch, Status
prüfen mit:

```bash
tail -n 30 /var/log/n8n-setup.log
```

### 4. n8n-Setup-Wizard durchlaufen

URL im Browser öffnen, n8n fragt nach Owner-Account-Daten (E-Mail, Passwort).
Diese Anmeldedaten gelten nur für diese Instanz.

> *(Screenshot-Platzhalter: docs/screenshots/04-setup-wizard.png)*

> **TLS-Hinweis:** Das Zertifikat wird beim ersten Aufruf bedarfsgesteuert
> (`on_demand`) von Let's Encrypt geholt. Die erste Anfrage dauert 5–10
> Sekunden länger als spätere. Bei Fehlern siehe
> [docs/troubleshooting.md](docs/troubleshooting.md).

---

## Nach dem Setup

### Erste Schritte in n8n

n8n bietet einen integrierten Workflow-Editor. Anregungen:

- Einfacher Webhook-Trigger → HTTP-Request → Slack-Nachricht
- Cron-Trigger → Datenbank-Abfrage → E-Mail
- Erweiterte Beispiele: Kursmaterial der Veranstaltung

Die n8n-Doku unter [docs.n8n.io](https://docs.n8n.io) ist die primäre
Referenz; die hier installierte Version ist 2.20.x.

### Server nach Kursende löschen

> **Pflicht-Schritt für jede Studierende und jeden Studierenden.**
> Server, die niemand mehr nutzt, kosten Geld und vergrößern die
> Angriffsfläche. Anleitung: [docs/server-loeschen.md](docs/server-loeschen.md)

Wer Workflows behalten möchte, exportiert sie vorher als JSON und sichert
zusätzlich die `.env`-Datei lokal (sie enthält den Encryption-Key, ohne
den die gesicherten Credentials wertlos sind).

### Backup einrichten

Manuelles Backup laufen lassen:

```bash
ssh root@<server-ip>
/opt/n8n/scripts/backup.sh
```

Sichert Postgres-Dump, n8n-Daten und `.env` nach `/opt/n8n/backups/`. Die
sieben jüngsten Sätze bleiben erhalten.

Optionaler Cron für tägliches Backup um 03:00 Uhr (auf dem Server):

```bash
( crontab -l 2>/dev/null; echo "0 3 * * * /opt/n8n/scripts/backup.sh >> /var/log/n8n-backup.log 2>&1" ) | crontab -
```

> **Hinweis:** Das Backup liegt auf demselben Server. Bei Server-Verlust
> ist es weg. Wer Workflows behalten möchte, kopiert die Backups regelmäßig
> per `scp` lokal:
> ```bash
> scp -r root@<server-ip>:/opt/n8n/backups ./
> ```

### Updaten

Im Repo auf dem Server `.env` anpassen (`N8N_IMAGE_TAG=…`), dann:

```bash
/opt/n8n/scripts/update.sh
```

Vorher wird automatisch ein Backup gezogen.

---

## Architektur, Datenschutz, EU AI Act

- [docs/architektur.md](docs/architektur.md) – Komponenten und Datenflüsse
- [docs/dsgvo.md](docs/dsgvo.md) – AVV mit Hetzner, Drittlandtransfer,
  Telemetrie-Reflex
- [docs/eu-ai-act.md](docs/eu-ai-act.md) – Risikoklassen anhand
  typischer n8n-Workflows
- [docs/troubleshooting.md](docs/troubleshooting.md) – häufige Probleme
- [docs/server-loeschen.md](docs/server-loeschen.md) – Pflicht nach Kursende

## Lizenz

[MIT](LICENSE)

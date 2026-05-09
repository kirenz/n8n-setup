# Troubleshooting

## Provisioning hängt oder bricht ab

```bash
ssh root@<server-ip>
sudo cloud-init status --long
sudo tail -n 100 /var/log/cloud-init-output.log
sudo tail -n 100 /var/log/n8n-setup.log
```

`cloud-init status --long` zeigt, ob das Setup noch läuft, fertig ist
oder gescheitert ist. Bei Fehlern liefert `n8n-setup.log` den genauen
Schritt.

Manueller Re-Run nur des Setup-Skripts (idempotent):

```bash
sudo /usr/local/sbin/n8n-setup.sh
```

## Browser zeigt Zertifikatsfehler oder Timeout

Caddy holt das TLS-Zertifikat **on-demand**, das heißt erst beim ersten
Aufruf. Der erste Request kann 5–10 Sekunden dauern. Wenn nach mehreren
Minuten immer noch ein Fehler kommt: in den Caddy-Logs nachsehen.

```bash
cd /opt/n8n
docker compose logs caddy | tail -n 50
```

Häufige Ursachen:

- **Cloud-Init noch nicht fertig** → eine Minute warten, dann neu probieren
- **DNS-Glitch bei sslip.io** → Domain im Browser per IP testen
  (HTTP, kein HTTPS): `http://<ip>` – ergibt 308 Redirect auf HTTPS, was
  schon ein guter Test ist
- **Let's Encrypt Rate Limit** → siehe nächster Abschnitt

## Let's Encrypt Rate Limit (sslip.io-Spezifikum)

**Hintergrund:** sslip.io ist nicht auf der Public Suffix List eingetragen.
Let's Encrypt zählt deshalb alle `*.sslip.io`-Subdomains als **eine
einzige Registered Domain** – mit gemeinsamem Limit von 50 Zertifikaten
pro Woche, weltweit über alle sslip.io-Nutzer hinweg.

In der Praxis ist das meistens kein Problem (sslip.io wird selten genug
genutzt). Bei einer Klasse mit 20+ Studierenden, die *gleichzeitig*
ihren ersten Zertifikatsantrag stellen, kann es allerdings knallen.

**Symptome im Caddy-Log:**

```
acme: error: 429 :: too many certificates already issued
```

**Workarounds:**

1. **Warten und retry**: das Limit ist gleitend; nach einigen Stunden
   funktioniert es wieder. Caddy retry t automatisch mit Backoff.
2. **Onboarding staffeln**: Studierende über mehrere Tage oder
   Übungs-Slots hinweg ihre Server starten lassen.
3. **Eigene Domain nutzen** (robusteste Lösung für produktiven Einsatz):
   eigene Domain bei einem Registrar holen, A-Record auf die Server-IP
   setzen, `DOMAIN` in `.env` auf die eigene Domain ändern, Container
   neu starten.
4. **Caddy-Staging-CA** (zum reinen Testen): in der Caddyfile-Option
   `acme_ca https://acme-staging-v02.api.letsencrypt.org/directory`
   setzen. Die Staging-Zertifikate sind nicht von Browsern als gültig
   anerkannt, aber das Limit ist viel höher.

## Container-Restart-Loop

```bash
docker compose ps
docker compose logs <servicename> --tail=50
```

Häufige Ursachen:

- **n8n bekommt keine Postgres-Verbindung**: Healthcheck noch nicht durch,
  zwei Minuten warten. Wenn dauerhaft: `POSTGRES_PASSWORD` in `.env`
  passt nicht zu dem in der laufenden Postgres-Instanz. Lösung:
  `docker compose down -v` (löscht Volumes!) und Setup neu starten.
  → **Vorsicht**: `-v` löscht alle Daten.
- **Caddy: `unable to start; cause: ...`**: meist ein Syntax-Problem im
  Caddyfile. `docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile`.

## Webhook-URL stimmt nicht

n8n leitet Webhook-URLs aus `WEBHOOK_URL` in `.env` ab. Wenn ein externer
Dienst beim Aufruf einen Fehler bekommt, prüfen:

- `.env`-Wert von `WEBHOOK_URL` muss `https://<DOMAIN>/` sein (mit
  abschließendem Slash, mit https)
- Nach Änderung: `docker compose up -d` (Restart von n8n)

## Speicher voll

```bash
df -h
docker system df
```

Wenn `/var/lib/docker` voll läuft: alte Backups prüfen
(`/opt/n8n/backups/`), n8n-Execution-Daten in der Datenbank prunen
(in n8n unter Settings → Executions Data Pruning oder via Env-Variable
`EXECUTIONS_DATA_PRUNE_MAX_AGE`).

Auf CPX11 mit 2 GB RAM: bei AI-Workflows mit großen Payloads kann es
OOM-Kills geben. Lösung entweder:

- Server auf CPX21 (4 GB) hochstufen (in der Hetzner-Console möglich
  ohne Datenverlust)
- Workflows so umbauen, dass weniger Daten parallel im Speicher sind

## Logs einsehen

```bash
# Setup-Log (Cloud-Init-Phase)
sudo tail -f /var/log/n8n-setup.log

# Container-Logs (laufender Betrieb)
cd /opt/n8n
docker compose logs -f                # alle
docker compose logs -f n8n            # nur n8n
docker compose logs -f caddy --tail=100

# Docker-Daemon-Probleme
sudo journalctl -u docker -n 50
```

## Server komplett neu aufsetzen

Im Notfall: Server in der Hetzner-Console löschen und neuen mit demselben
Cloud-Init-Inhalt erstellen. Vorher aber Backups lokal sichern, sonst
sind die Workflows weg!

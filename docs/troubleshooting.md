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

Caddy holt das TLS-Zertifikat beim Start für den festen Hostnamen aus
`DOMAIN`. Das Setup-Skript meldet erst Erfolg, wenn `https://<domain>/healthz`
antwortet. Wenn danach immer noch ein Fehler kommt: in den Caddy-Logs
nachsehen.

```bash
cd /opt/n8n
docker compose logs caddy | tail -n 50
```

Häufige Ursachen:

- **Cloud-Init noch nicht fertig** → eine Minute warten, dann neu probieren
- **DNS-Glitch bei sslip.io** → `http://<ip-mit-bindestrichen>.sslip.io`
  (HTTP, kein HTTPS) aufrufen: ergibt einen Redirect auf HTTPS, wenn der
  Server erreichbar ist (im Test 2026-10-30: 308 auf HTTPS).
- **Let's Encrypt Rate Limit** → siehe nächster Abschnitt

## Let's Encrypt Rate Limit (sslip.io-Spezifikum)

**Hintergrund:** Let's Encrypt zählt alle `*.sslip.io`-Subdomains als
eine gemeinsame Registered Domain. Laut Betreiber (nip.io, Stand Oktober
2026) hat Let's Encrypt das gemeinsame Kontingent von 50 auf 250.000
Zertifikate pro Woche angehoben. Ein Engpass ist damit selten, aber nicht
ausgeschlossen.

**Symptome im Caddy-Log:**

```
acme: error: 429 :: too many certificates already issued
```

**Workarounds:**

1. **Auf nip.io ausweichen**: In `.env` die Domain in `DOMAIN`, `N8N_HOST`
   und `WEBHOOK_URL` von `…sslip.io` auf `…nip.io` umstellen, dann
   `docker compose up -d`. Beide Dienste lösen gleich auf.
2. **Warten und retry**: das Limit ist gleitend; nach einigen Stunden
   funktioniert es wieder. Caddy versucht es automatisch mit Backoff erneut.
3. **Onboarding staffeln**: Studierende über mehrere Tage oder
   Übungs-Slots hinweg ihre Server starten lassen.
4. **Eigene Domain nutzen** (robusteste Lösung für produktiven Einsatz):
   eigene Domain bei einem Registrar holen, A-Record auf die Server-IP
   setzen, `DOMAIN`, `N8N_HOST` und `WEBHOOK_URL` in `.env` ändern,
   `docker compose up -d`.
5. **Caddy-Staging-CA** (zum reinen Testen): in der Caddyfile-Option
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

## Bestimmte Nodes fehlen im Workflow-Editor

Wenn die Suche im Editor keine **Execute Command**- oder
**Local File Trigger**-Node findet: Das ist Absicht. n8n 2.x deaktiviert
diese beiden Nodes per Default, weil sie beliebige Shell-Befehle bzw.
Dateisystem-Zugriff erlauben – im Multi-User-Setup oder bei kompromittierten
Credentials wäre das ein direkter Pfad zur Server-Übernahme.

**Reaktivierung:** in `.env` die Variable `NODES_EXCLUDE` explizit auf eine
Liste setzen, die die gewünschten Nodes nicht mehr enthält:

```bash
# Im /opt/n8n auf dem Server:
echo 'NODES_EXCLUDE=[]' >> .env
docker compose up -d
```

`NODES_EXCLUDE=[]` (leeres Array) reaktiviert alle Nodes; alternativ eine
gezielte Liste setzen, die die ausgeschlossenen Nodes außer den gewünschten
enthält. Format laut n8n-Doku:

```bash
NODES_EXCLUDE=["n8n-nodes-base.executeCommand"]
```

**Vor der Reaktivierung abwägen:** Wer einer Studierenden Execute Command
freischaltet, gibt ihr in der Konsequenz Root-äquivalenten Zugriff auf den
Container. Im Kurs-Kontext (jede/r läuft auf eigenem Server) ist das vertretbar,
in geteilten Setups nicht.

Hintergrund: [n8n 2.0 Breaking Changes – Node Security](https://docs.n8n.io/2-0-breaking-changes/)

## Speicher voll

```bash
df -h
docker system df
```

Wenn `/var/lib/docker` voll läuft: alte Backups prüfen
(`/opt/n8n/backups/`), n8n-Execution-Daten in der Datenbank prunen
(Env-Variablen `EXECUTIONS_DATA_MAX_AGE` in Stunden und
`EXECUTIONS_DATA_PRUNE_MAX_COUNT` in `.env` senken, dann
`docker compose up -d`).

Auf CPX12 mit 2 GB RAM: bei AI-Workflows mit großen Payloads kann es
OOM-Kills geben. Lösung entweder:

- Server auf CPX22 (4 GB) hochstufen (in der Hetzner-Console möglich
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

# Architektur

## Überblick

Drei Container im selben Docker-Netzwerk, abgeschirmt durch zwei
Firewall-Schichten.

```
                             Internet
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Hetzner Cloud Firewall │  ← Provider-Ebene
                    └───────────┬───────────┘
                                │ nur 22/80/443
                                ▼
                    ┌───────────────────────┐
                    │   UFW (Server-Ebene)  │  ← Defense-in-Depth
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Caddy   (80/443)    │  TLS-Terminierung,
                    │   Reverse Proxy        │  Auto-SSL via Let's Encrypt
                    └───────────┬───────────┘
                                │ HTTP intern
                                ▼
                    ┌───────────────────────┐
                    │   n8n     (5678)      │  Workflow-Engine
                    └───────────┬───────────┘
                                │ Postgres-Wire
                                ▼
                    ┌───────────────────────┐
                    │   Postgres (5432)     │  Workflows, Credentials,
                    │                        │  Executions
                    └───────────────────────┘
                            (intern)
```

## Schichten und Verantwortlichkeiten

### Hetzner Cloud Firewall

Provider-Ebene. Filtert bevor Pakete den Server überhaupt erreichen.
Konfiguriert über die Hetzner-Console: nur eingehende Verbindungen auf
22 (SSH), 80 (HTTP) und 443 (HTTPS) erlaubt, alles andere fällt schon
hier.

### UFW (Uncomplicated Firewall)

Server-Ebene als zweite Schicht. Vom Cloud-Init mit identischen Regeln
konfiguriert. Sinn: Defense-in-Depth – falls die Cloud-Firewall
versehentlich falsch konfiguriert wird, bleibt der Server geschützt.

### Caddy

Einziger Container mit Port-Mapping nach außen. Übernimmt:

- TLS-Terminierung (Let's Encrypt automatisch, `on_demand` mit Allowlist)
- HSTS-Header
- Reverse-Proxy auf `n8n:5678`
- Korrekte Weiterleitung der Webhook-relevanten Header
  (`Host`, `X-Forwarded-Proto`, `X-Real-IP`, `X-Forwarded-For`)

Persistenz der ausgestellten Zertifikate über das Volume `caddy_data` –
wichtig wegen des Let's-Encrypt-Rate-Limits (siehe
[troubleshooting.md](troubleshooting.md)).

### n8n

Hört intern auf 5678. Speichert Workflows, Credentials und Execution-Logs
in Postgres. User-Settings, Custom-Nodes und Logs liegen im Volume
`n8n_data`.

Ausgehende Calls (z. B. zu OpenAI/Anthropic-APIs aus AI-Nodes) laufen
direkt vom n8n-Container nach außen und sind durch keine der Firewalls
blockiert.

### Postgres

Hört intern auf 5432, **kein** Port-Mapping nach außen. Daten im Volume
`postgres_data`. Healthcheck via `pg_isready` – n8n startet erst, wenn
Postgres antwortet.

## Datenflüsse

### Eingehende Webhook-Anfrage

```
Externe API ─HTTPS─> Caddy ─HTTP─> n8n
                     (Host-Header bleibt erhalten,
                      damit n8n die Webhook-URL korrekt zuordnet)
```

### Workflow-Ausführung mit AI-Node

```
n8n ──HTTPS──> openai.com / anthropic.com  (Drittlandtransfer!)
              ── siehe docs/dsgvo.md
```

### Outbound-Telemetrie (im Kurs deaktiviert)

```
n8n ──> n8n.io  (Diagnostics, Version-Check, Personalization)
        Drei Variablen in .env auf false:
          N8N_DIAGNOSTICS_ENABLED, N8N_VERSION_NOTIFICATIONS_ENABLED,
          N8N_PERSONALIZATION_ENABLED
```

## Persistenz

| Volume          | Inhalt                                      | Backup-Quelle      |
| --------------- | ------------------------------------------- | ------------------ |
| `postgres_data` | alle Workflows, Credentials, Executions     | `pg_dump`          |
| `n8n_data`      | User-Settings, Custom-Nodes, lokale Logs    | tar aus Container  |
| `caddy_data`    | Let's-Encrypt-Zertifikate                   | nicht gesichert    |
| `caddy_config`  | Caddy-Runtime-Config                        | nicht gesichert    |

`caddy_data` wird bewusst nicht gesichert: Zertifikate kann Caddy bei
Bedarf neu anfordern. Backup siehe [scripts/backup.sh](../scripts/backup.sh).

## Reproduzierbarkeit

Alle Container-Images sind auf konkrete Patch-Versionen gepinnt
(siehe [.env.example](../.env.example)). Eine Studierende, die das
Repo zu Semesterbeginn klont, bekommt dieselbe Version wie alle anderen.

Updates sind ein bewusster Schritt: Tag in `.env` hochziehen, dann
`scripts/update.sh` laufen lassen. Davor wird automatisch gesichert.

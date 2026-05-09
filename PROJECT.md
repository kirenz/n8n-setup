# Projekt-Briefing: n8n-Hetzner-Kurs-Setup

## Kontext

Open-Source-Repo zur Begleitung eines Kurses an der HdM Stuttgart (Prof. Jan
Kirenz, Generative AI / Agentic AI / Data Science). Wiederverwendbar für
Trainings bei VWA, Kärcher und weitere Corporate-Kunden über kirenz.de.

**Multi-Audience-Anforderung** (durchgehend mitgedacht):

- **Studierende:** didaktisch aufbereitet, mit Erklärungen und Screenshots
- **Technische Zielgruppe:** sauberer, kommentierter Code als Referenz
- **Executives** (über Begleit-Blogpost): Architektur und
  Souveränitäts-Argumente verständlich

## Ziel des Repos

Studierende sollen in unter 10 Minuten eine produktionsähnliche,
DSGVO-konforme n8n-Instanz auf Hetzner Cloud einrichten können – ohne
Vorerfahrung mit Linux-Servern, aber mit dem klaren Ziel, dass sie die
Architektur verstehen.

## Architektur-Entscheidungen (begründet)

| Entscheidung                            | Warum                                                                                                  |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Hetzner Cloud (Nürnberg/Falkenstein)    | DSGVO-konform, deutsches Unternehmen, AVV nach Art. 28 DSGVO, ~4–7 €/Monat                             |
| Cloud-Init für Provisioning             | Industriestandard, transparent, übertragbar auf andere Provider                                        |
| Docker Compose (statt Coolify/One-Click) | Transparenz vor Komfort – Studierende sollen die Schichten verstehen                                  |
| Postgres statt SQLite                   | Produktionsnaher Setup, Kursinhalt damit auch für reale Projekte tragfähig                             |
| Caddy als Reverse Proxy                 | Auto-SSL via Let's Encrypt, deutlich weniger Konfigurationsaufwand als Nginx                            |
| sslip.io als DNS                        | Keine eigene Domain nötig (didaktischer Vorteil); bekannte Einschränkung beim Let's-Encrypt-Rate-Limit |
| Caddy `on_demand` TLS                   | Zertifikate werden bedarfsgesteuert geholt; Allowlist verhindert Missbrauch                            |
| Spezifisches Versionspinning            | Reproduzierbarkeit über das Semester, keine Breaking-Change-Überraschungen                              |
| Hetzner Cloud Firewall + UFW            | Defense-in-Depth (Provider-Ebene + Server-Ebene)                                                        |
| Ubuntu 24.04 LTS                        | Hetzner-Default, lange Support-Laufzeit                                                                  |

## Tech-Stack (Versionen gepinnt)

- Hetzner Cloud Server: **CPX11** (2 vCPU, 2 GB RAM) als Minimum oder
  **CPX21** (2 vCPU, 4 GB RAM) als Empfehlung
- OS: **Ubuntu 24.04 LTS**
- Docker: aus Ubuntu-Repos (`docker.io`)
- n8n: **`n8nio/n8n:2.20.6`** – wir starten direkt auf der aktuellen
  Major-Version 2.x (stabil seit Anfang 2026, Setup ist „2.0-ready").
  Patch-Pinning übers Semester, vor jedem neuen Semester wird bewusst
  auf eine neuere Stable-Version gehoben. Keine automatischen
  Updates während eines laufenden Semesters.
- Postgres: **`postgres:16.13-alpine3.23`**
- Caddy: **`caddy:2.11.2-alpine`**
- DNS: **sslip.io** (kein eigenes DNS-Setup für den Kurs)

## Pädagogische Anforderungen

- **Telemetrie-Reflex:** Studierende sollen lernen, *jede einzelne*
  Telemetrie-Option bewusst zu prüfen. Im Kurs-Default sind drei n8n-Variablen
  auf `false` gesetzt (Diagnostics, Version-Notifications, Personalization);
  jede mit Begründung in `.env.example` und in `docs/dsgvo.md`.
- **Souveränitäts-Argument:** EU-Hosting ist nur die halbe Miete – sobald
  AI-Nodes mit OpenAI/Anthropic im Workflow stecken, beginnt der
  Drittlandtransfer. Souveräne Alternativen werden in `docs/dsgvo.md` benannt.
- **EU AI Act:** trifft Use Case, nicht Tool. `docs/eu-ai-act.md` erklärt
  Risikoklassen anhand typischer n8n-Workflows.
- **Verantwortung nach Kursende:** `docs/server-loeschen.md` macht
  Workflow-Export und `.env`-Sicherung (mit Encryption-Key) zur Pflicht
  vor dem Server-Delete.

## Konventionen

- **Sprache:** Deutsch in Kommentaren und Doku, indirekte Ansprache
  (kein „Sie", kein „du")
- **Code-Stil:** Kommentare über Code-Blöcken erklären das *Warum*,
  nicht das *Was*
- **Versionspinning:** alle Container-Images mit konkretem Patch-Tag,
  kein `latest`
- **Sicherheit by Default:** keine Default-Passwörter, alle Secrets werden
  beim Provisioning generiert
- **Beobachtbarkeit:** Setup-Log in `/var/log/n8n-setup.log`, Container-Logs
  einsehbar, Healthchecks aktiv

## Out of Scope (für v1)

- Coolify-Integration (kann als optionales Bonus-Modul folgen)
- High-Availability oder Queue-Mode (für Lehrkontext nicht nötig)
- Eigene Domain mit DNS-Einträgen (sslip.io reicht für den Kurs)
- Externe Backup-Targets (Hetzner Storage Box, S3) – lokales Backup reicht
  für Phase 1
- Multi-User-n8n-Setup (Studierende laufen jeweils auf eigenem Server)

# AGENTS.md

Hinweise für Claude Code (oder andere LLM-basierte Assistenten), die in
diesem Repo arbeiten. Stand: 2026-05-09.

## Was dieses Repo ist

Begleitendes Setup-Repo für Kurse und Trainings von Jan Kirenz zum Thema
n8n auf Hetzner Cloud. Studierende sollen in <10 Minuten eine
DSGVO-konforme, produktionsähnliche n8n-Instanz aufsetzen können – und
dabei die Architektur verstehen.

Das volle Briefing liegt in [PROJECT.md](PROJECT.md). Architektur-
Entscheidungen (warum Caddy, warum sslip.io, warum Versionspinning) sind
dort begründet.

## Locked-in Decisions (nicht ohne Rückfrage ändern)

| Entscheidung                              | Warum                                                     |
| ----------------------------------------- | --------------------------------------------------------- |
| n8n auf 1.x bleiben (Minor-/Patch-Pinning) | Reproduzierbarkeit über das Semester                      |
| Caddy mit `on_demand` TLS und Allowlist   | Schutz vor Cert-Flooding fremder Domains                  |
| sslip.io statt eigener Domain              | Studierende ohne eigenes Setup sollen sofort arbeiten können |
| Postgres statt SQLite                      | Produktionsnaher Setup                                    |
| Hetzner Cloud Firewall + UFW              | Defense-in-Depth                                          |
| Lokales Backup (kein S3/StorageBox)       | v1-Scope; Studierende sichern Backups per `scp` nach lokal |
| Sprache: Deutsch, indirekte Ansprache      | Convention für alle Kirenz-Lehrrepos                       |

## Repo-Struktur

```
n8n-hetzner-kurs/
├── README.md                 ← Studierenden-Tutorial
├── AGENTS.md                 ← diese Datei
├── PROJECT.md                ← vollständiges Briefing
├── LICENSE                   ← MIT
├── .gitignore
├── cloud-init.yaml           ← Hetzner User-Data (Provisioning)
├── docker-compose.yml        ← n8n + Postgres + Caddy
├── Caddyfile                 ← Reverse Proxy mit on_demand TLS
├── .env.example              ← Konfig-Template, ausführlich kommentiert
├── scripts/
│   ├── backup.sh
│   └── update.sh
└── docs/
    ├── architektur.md
    ├── dsgvo.md
    ├── eu-ai-act.md
    ├── troubleshooting.md
    └── server-loeschen.md
```

## Konventionen

- **Sprache:** Deutsch in Kommentaren, Doku, Commit Messages. Indirekte
  Ansprache („Server löschen") statt „Sie löschen den Server" oder
  „Lösche den Server".
- **Code-Kommentare:** über dem Code-Block, erklären das *Warum*, nicht
  das *Was*.
- **Versionspinning:** alle Container-Images mit konkretem Patch-Tag.
  Keine `latest`-Tags, kein `1`-Major-Tag.
- **Secrets:** niemals einchecken. `.env` ist in `.gitignore`. Cloud-Init
  generiert Secrets beim ersten Boot mit `openssl rand`.
- **Default-deny:** Firewalls ablehnend, Ports nur öffnen wenn nötig.
  Postgres und n8n haben kein Port-Mapping nach außen.

## Häufige Aufgaben

### Vor jedem Semester: Versionen prüfen

```bash
# Aktuell stable n8n 1.x?
curl -s "https://hub.docker.com/v2/repositories/n8nio/n8n/tags?page_size=50" \
  | jq -r '.results[].name' | grep -E '^1\.' | head -5

# Aktuell stable postgres 16?
curl -s "https://hub.docker.com/v2/repositories/library/postgres/tags?page_size=50&name=16" \
  | jq -r '.results[].name' | grep alpine | head -5

# Aktuell stable caddy 2?
curl -s "https://hub.docker.com/v2/repositories/library/caddy/tags?page_size=50&name=2" \
  | jq -r '.results[].name' | grep alpine | grep -v builder | head -5
```

Tags in `.env.example`, `docker-compose.yml` und `PROJECT.md` aktualisieren.
Auf einem Test-Server verifizieren, bevor der Kurs startet.

### Compose-Datei validieren

```bash
cd /Users/jankirenz/code/n8n-hetzner-kurs
docker compose --env-file .env.example config >/dev/null
```

### Cloud-Init testen (lokal, ohne echten Server)

```bash
cloud-init devel schema --config-file cloud-init.yaml
```

(`cloud-init`-Tools müssen lokal installiert sein: `brew install cloud-init`
oder online-Validator.)

### Auf echtem Hetzner-Server verifizieren

Eine CPX11-Instanz erstellen, `cloud-init.yaml` als User Data einfügen,
nach 5–8 Min die in `/etc/motd` ausgegebene URL aufrufen, n8n-Setup-Wizard
durchspielen, danach `scripts/backup.sh` und `scripts/update.sh` testen.
Server am Ende löschen.

## Was NICHT tun

- **Kein `latest`-Tag** für irgendein Image. Reproduzierbarkeit ist Pflicht.
- **Kein `--no-verify`** bei Commits.
- **Keine direkten Pushes auf `main` mit Breaking Changes** während ein
  Semester läuft. Wenn unsicher: in einem Branch testen, mit Jan Rücksprache
  halten.
- **Keine Default-Passwörter** im Code oder in `.env.example`. Alles wird
  generiert (`openssl rand …` in cloud-init.yaml) oder muss vom User
  gesetzt werden.
- **Keine Standalone-Doku-Dateien außerhalb von `docs/`** anlegen, wenn
  sie nicht mit dem Briefing verankert sind.

## Multi-Audience-Reflex

Bei allen Änderungen mitdenken:

- **Studierende** sollen die Schritte ausführen können → didaktische
  Klarheit, Screenshots-Platzhalter
- **Tech-Zielgruppe** soll den Code lesen können → kommentierte Quellen
- **Executives** lesen den Begleit-Blogpost (nicht hier im Repo) →
  Architektur-Begründungen müssen in einfacher Sprache verfügbar sein
  (`PROJECT.md`, `docs/architektur.md`)

## Kontakt / Quellen

- Briefing-Quelle und Entscheidungs-Trail: [PROJECT.md](PROJECT.md)
- Verwandte Konventionen: `~/code/hdm/lernplattform/AGENTS.md` (für
  Lehrrepo-Stil im Allgemeinen)
- Ansprechpartner: Jan Kirenz

# n8n einrichten

Begleitmaterial zum n8n-Kurs an der HdM Stuttgart und zu Trainings über
kirenz.de. Das Repo vereint ein **Quarto-Buch** für Anfänger mit der
**lauffähigen Infrastruktur** für eine eigene n8n-Instanz.

**Buch (Live-Version):** <https://kirenz.github.io/n8n-setup/>

Das Buch zeigt vier Wege zu einer laufenden n8n-Instanz: lokal auf dem eigenen
Rechner, in der n8n Cloud, über Managed Hosting und als eigener, EU-souveräner
Server bei Hetzner. Dazu kommen Betrieb (Backups, Updates, Server löschen) und
ein Modul zu Datenschutz und EU AI Act.

## Struktur

```
.
├── *.qmd, lokal/, gehostet/,        ← Buch-Kapitel (Quarto)
│   hetzner/, betrieb/, souveraenitaet/
├── _quarto.yml, book-theme.scss     ← Buch-Konfiguration und Hausstil
├── references.bib                   ← Bibliografie
│
├── cloud-init.yaml                  ← Hetzner-Provisioning (eine Datei genügt)
├── docker-compose.yml               ← n8n + Postgres + Caddy
├── Caddyfile, .env.example          ← Reverse Proxy, Konfig-Template
├── scripts/                         ← backup.sh, update.sh
└── docs/                            ← Quell-Notizen zu Architektur, DSGVO, EU AI Act
```

## Buch bauen und veröffentlichen

Voraussetzung: [Quarto](https://quarto.org).

```bash
quarto render            # rendert das Buch nach _book/
quarto publish gh-pages  # veröffentlicht auf GitHub Pages
```

## Eigene Hetzner-Instanz starten

Die Schritt-für-Schritt-Anleitung steht im
[Hetzner-Modul des Buchs](https://kirenz.github.io/n8n-setup/hetzner/). Kurz:
in der Hetzner-Console eine Firewall (22/80/443) anlegen, einen Server mit
Ubuntu 24.04 erstellen und den kompletten Inhalt von
[`cloud-init.yaml`](cloud-init.yaml) ins Feld „Cloud-Config" einfügen. Nach 5
bis 8 Minuten ist n8n unter `https://<ip>.sslip.io` erreichbar.

Der Stack ist versionsgepinnt (n8n `2.20.6`, Postgres `16.13`, Caddy `2.11.2`);
Telemetrie ist im Kurs-Default deaktiviert. Begründungen in
[PROJECT.md](PROJECT.md) und [docs/dsgvo.md](docs/dsgvo.md).

## Stand

| Modul | Buch-Kapitel |
|---|---|
| Lokal (npx, Docker) | ✅ |
| Gehostet (Cloud, Managed) | ✅ |
| Hetzner (Architektur, Server, Einrichten) | ✅ |
| Betrieb (Backups, Update, Löschen) | ✅ |
| Souveränität (Datenschutz, EU AI Act) | ✅ |
| Folien-Decks | später (Repo mono-repo-tauglich) |

## Lizenz

[MIT](LICENSE)

Hinweise für KI-Assistenten: [AGENTS.md](AGENTS.md).

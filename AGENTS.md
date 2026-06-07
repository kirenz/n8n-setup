# AGENTS.md — n8n einrichten (Buch + Infrastruktur)

Dieses Dokument ist die **kanonische Quelle der Wahrheit** für jede KI, die in
diesem Repo arbeitet. Wenn andere Dokumente widersprechen, gilt AGENTS.md.

Das Repo vereint zwei Welten:

1. **Das Quarto-Buch** „n8n einrichten" (Stil-Vorbild: `kurse/n8n-grundlagen`).
2. **Die kursbegleitende Infrastruktur** (lauffähiger Hetzner-Stack), deren
   Briefing in [PROJECT.md](PROJECT.md) steht.

---

## Repo-Struktur

```
.
├── _quarto.yml               # Buch-Build-Konfiguration (project: book)
├── AGENTS.md                 # Dieses Regelwerk
├── PROJECT.md                # Infra-Briefing (Architektur-Entscheidungen)
├── README.md                 # Repo-Beschreibung
├── book-theme.scss           # Hausstil (Schwester-Datei zu n8n-grundlagen)
├── references.bib            # Bibliografie für Buch-Zitate
│
│  # — Buch-Welt (kanonische Quelle) —
├── index.qmd                 # Willkommen
├── introduction.qmd          # Bausteine-Glossar + Wege-Orientierung
├── lokal/                    # Modul: npx, Docker
├── gehostet/                 # Modul: n8n Cloud, Managed Hosting
├── hetzner/                  # Modul: Architektur, Server anlegen, Einrichten
├── betrieb/                  # Modul: Backups, Aktualisieren, Server löschen
├── souveraenitaet/           # Modul: Datenschutz, EU AI Act
│
│  # — Kursbegleitende Infrastruktur (kein Buch-Inhalt) —
├── cloud-init.yaml           # Hetzner-Provisioning
├── docker-compose.yml        # n8n + Postgres + Caddy
├── Caddyfile                 # Reverse Proxy, on_demand TLS
├── .env.example              # Konfig-Template, kommentiert
├── scripts/                  # backup.sh, update.sh
└── docs/                     # Quell-Notizen (architektur, dsgvo, eu-ai-act, …)
```

**Modul-Slug**: kebab-case, beschreibend, kein „modul-XX"-Präfix (Reihenfolge
steht in `_quarto.yml`). **Lesson-Slug**: kebab-case, beschreibt das Thema.

**Folien-Welt**: Aktuell ist nur das Buch aufgesetzt (Entscheidung des Nutzers).
Das Repo ist mono-repo-tauglich angelegt; eine `slides/`-Welt mit
`scripts/generate_slides.py` kann später nach dem Vorbild von `n8n-grundlagen`
ergänzt werden. **Buch-First-Prinzip**: Erst das Buch-Kapitel, dann ein Deck.

---

## Verbindliche Buch-Stilregeln

### 1. Sprach-Stil: Wir-Form

**In sichtbarem Buch-Text** durchgängig die **Wir-Form** („Wir legen ein
Volume an…"). Das ist der bewusste Unterschied zum Infra-Code, wo in den
Kommentaren die indirekte Ansprache gilt.

| Verwenden | Vermeiden |
|---|---|
| „Wir rufen die URL im Browser auf." | „Du rufst…" / „Sie rufen…" |
| „Wir sichern die `.env` lokal." | „Man sichert…" |
| „Drei Container reichen für den Start." | (auch okay, beschreibend ohne Anrede) |

### 2. Kein langer Gedankenstrich

In deutschem Fließtext **kein Em-Dash (—) und kein En-Dash (–)**. Stattdessen
Nebensätze, Kommas, Klammern oder Punkte. Für Zahlenbereiche „4 bis 7 €".

### 3. Callout-Disziplin

Drei Typen sind Standard: `.callout-tip` (Hinweise, Faustregeln, Analogien),
`.callout-note` (Hintergrund, Querverweise), `.callout-important`
(Pflicht-Aufmerksamkeit, Sicherheit, Fallstricke). Pro Kapitel **maximal 4 bis
5 Callouts**. **Title ist Pflicht** bei `.callout-tip` und `.callout-important`.
Längere Analogien mit `collapse="true"` einklappen.

### 4. Analogien aus der Berufsalltagswelt

Werkstatt, Büro, Empfang/Archiv, Bibliothek, Labor, Kontrollraum. **Nicht**
geeignet: Märchen, Zauberei, Cartoon-Tiere, Superhelden, Kindergarten-Beispiele.
Eine Analogie pro Begriff genügt.

### 5. Pro Lesson ein Kapitel

**Eine Lesson = ein `.qmd` = später ein Deck.** Pro Kapitel ein H1, mehrere H2,
optional H3. **Lernzeit 5 bis 15 Minuten.**

### 6. Hands-on-Kapitelstruktur

Kapitel, in denen etwas selbst gebaut wird, folgen dieser Reihenfolge:

1. Kurze Einleitung (1 bis 2 Sätze)
2. `## Zielbild` (Ergebnis plus Liste der Stationen)
3. `## Schritt für Schritt selbst bauen` mit `### Schritt 1`, `### Schritt 2`, …
4. `## Fehler diagnostizieren` (Symptom-Tabelle: Symptom, Ursache, nächster Schritt)
5. `## Kontrollpunkt` (Lernziele in Verb-Infinitiv-Form)

**Theorie steht in Callouts neben dem jeweiligen Schritt**, nicht in
Vorab-Theorie-Sektionen. Vorbild: `hetzner/server-anlegen.qmd`.

### 7. Keine Vorgriffe

Keine „in Modul X bauen wir …"-Hinweise und keine `Wie es weitergeht`-Sektion.
Querverweise sachlich-beschreibend formulieren, nicht als Teaser.

### 8. Disziplin-Verbote

- Direkt-Anrede (du, Sie) im Buch-Text; „man"-Konstruktionen
- Marketing-Sprache, Superlative, Selbst-Bewertung („anschaulich", „sauber")
- Lernenden-Anrede („für Einsteiger", „Teilnehmende"); beschreiben, was passiert
- Lange Code-Blöcke ohne erklärenden Folge-Callout
- Cartoon-Emojis im Fließtext (Ausnahme: Status-Marker in Tabellen)
- „das LLM" (Neutrum), nicht „der LLM"

---

## Index-Konventionen

- **`index.qmd`**: `Willkommen {.unnumbered}`, 2 bis 3 Absätze, nummerierte
  Liste der vier Wege, `.callout-note` (Companion-Hinweis), `.callout-tip`
  (Lernempfehlung).
- **`introduction.qmd`**: `Einführung {.unnumbered}`, Orientierungstabelle plus
  Begriffe in je zwei Sätzen.
- **Modul-`index.qmd`**: `<Titel> {.unnumbered}`, ein Absatz, „Wir werden …".

## Diagramme

Architektur-Diagramme als **gefenste Text-Blöcke** (rendern ohne Toolchain,
Vorbild: `hetzner/architektur.qmd`). Eine D2-Pipeline nach dem Vorbild von
`n8n-grundlagen` kann später ergänzt werden; keine gebrochenen Bild-Links
einchecken.

---

## Kursbegleitende Infrastruktur

Der lauffähige Stack ist die technische Grundlage von Modul 3 bis 5. Regeln
(Details in [PROJECT.md](PROJECT.md)):

- **Versionspinning**: alle Container-Images mit konkretem Patch-Tag, **kein
  `latest`**. Tags in `.env.example`, `docker-compose.yml` und `PROJECT.md`
  synchron halten.
- **Secrets**: nie einchecken (`.env` in `.gitignore`). Cloud-Init generiert sie
  mit `openssl rand`.
- **Indirekte Ansprache in Code-Kommentaren** (nicht Wir-Form): „Server löschen"
  statt „Wir löschen". Das gilt nur für Infra-Dateien, nicht für das Buch.
- **Default-deny**: Firewalls ablehnend, nur 22/80/443 offen.
- Bei inhaltlichen Änderungen am Stack die zugehörigen Buch-Kapitel mitziehen.

---

## Bauen und Veröffentlichen

```bash
# Buch lokal rendern
quarto render                      # Output in _book/

# Auf GitHub Pages veröffentlichen (Branch gh-pages)
quarto publish gh-pages
```

Die Live-Version liegt unter <https://kirenz.github.io/n8n-setup/>. GitHub Pages
bedient den `gh-pages`-Branch. **Vor jedem Publish `quarto render` ohne Errors.**
Das Buch-Output (`_book/`, `.quarto/`, `_freeze/`) ist in `.gitignore`; die
Buch-Quellen (`*.qmd`) und die Infra-Dateien liegen auf `main`.

---

## Validierung vor Commit

```bash
quarto render
```

Errors müssen behoben sein. Zusätzlich prüfen: keine langen Gedankenstriche,
keine Direkt-Anrede im Buch-Text, Callout-Titel gesetzt, Code-Blöcke erklärt.

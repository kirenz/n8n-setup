# DSGVO – Hinweise zum n8n-Hetzner-Setup

Diese Notizen sind kein Rechtsgutachten. Sie geben den datenschutzrelevanten
Kontext, den Studierende und Trainer für ein verantwortungsvolles Setup
brauchen. Im Zweifel rechtlichen Rat einholen.

## Auftragsverarbeitungsvertrag (AVV) mit Hetzner

Wer personenbezogene Daten in n8n speichert, lässt diese durch Hetzner
verarbeiten – damit liegt eine Auftragsverarbeitung nach Art. 28 DSGVO vor.
Hetzner stellt einen Standard-AVV bereit, der direkt in der Hetzner-Console
abgeschlossen werden kann (Bereich „Vertragsdokumente").

Praktischer Schritt vor dem ersten Echt-Workflow: AVV in der Console
abschließen, Bestätigungs-PDF lokal sichern.

Hetzner-Standorte: Nürnberg, Falkenstein, Helsinki – alle innerhalb der EU.
Diese Anleitung empfiehlt **Nürnberg oder Falkenstein**.

## Drittlandtransfer durch AI-Nodes

EU-Hosting ist nur die halbe Miete. Sobald in einem n8n-Workflow ein
AI-Node mit OpenAI, Anthropic oder einem anderen US-Anbieter steckt,
fließen die übergebenen Daten in die USA – das ist ein Drittlandtransfer
und braucht eine eigene Rechtsgrundlage (Standardvertragsklauseln,
Transfer-Impact-Assessment, ggf. Einwilligung der Betroffenen).

Konkret in n8n: jede AI-Node in einem Workflow ist ein Datenfluss-Punkt,
der dokumentiert werden muss.

### Souveränere Alternativen (bei Bedarf)

| Anbieter        | Sitz | Hosting | Bemerkung                                  |
| --------------- | ---- | ------- | ------------------------------------------ |
| Mistral         | FR   | EU      | API-kompatibel mit OpenAI                  |
| Aleph Alpha     | DE   | DE      | Enterprise-Fokus, Modell „Pharia"          |
| Ollama (lokal)  | –    | lokal   | Open-Source-Modelle auf dem eigenen Server |

Für AI-Nodes mit besonders sensiblen Daten ist Ollama auf einem Hetzner-Server
ein gangbarer Weg – Hardware-Anforderungen beachten (für 7B-Modelle reichen
~8 GB RAM, für 70B-Modelle braucht es GPU oder CCX-Server).

## Datenflussdiagramm-Pflicht

Für eigene produktive Workflows: Datenflussdiagramm erstellen und im
Verzeichnis von Verarbeitungstätigkeiten (Art. 30 DSGVO) hinterlegen.
Pflicht-Felder pro Workflow:

- Welche Daten werden verarbeitet (Kategorien, Betroffene)?
- Welche Knoten verarbeiten sie wo (EU/Drittland)?
- Welche Rechtsgrundlage liegt vor?
- Wie werden die Daten gelöscht?

## Telemetrie-Reflex

n8n schickt im Default drei Outbound-Datenströme zu n8n.io. Im
Kurs-Setup sind alle drei deaktiviert. Tabelle als pädagogisches Modell –
*die Reflexfrage „was schickt mein Open-Source-Tool nach Hause?" gilt für
jede neue Software*.

| Variable                              | Was passiert                                                  | Welche Daten potenziell                                          | Kurs-Default | Eigennutzung empfohlen                                                          |
| ------------------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------- | ------------ | ------------------------------------------------------------------------------- |
| `N8N_DIAGNOSTICS_ENABLED`             | Anonyme Telemetrie über App-Nutzung, Features, Crashes        | Pseudonyme Instanz-ID, Workflow-Anzahl, Feature-Klicks, Errors   | `false`      | weiterhin `false` – klassisches Tracking, Opt-in nur mit klarer Begründung      |
| `N8N_VERSION_NOTIFICATIONS_ENABLED`   | Polling zu n8n.io zur Prüfung neuer Versionen                 | Instanz-ID, aktuelle Version, IP via Standard-HTTP                | `false`      | `true` durchaus sinnvoll – sichtbare Security-Patches sind Sicherheitsgewinn    |
| `N8N_PERSONALIZATION_ENABLED`         | Onboarding-Wizard fragt Profil ab und schickt es an n8n.io   | Rolle, Unternehmensgröße, Tool-Stack der Person                  | `false`      | `true` ist ein fairer Tausch (relevantere Templates), kein Datenschutz-Problem  |

Die didaktische Pointe: Studierende sollen sich angewöhnen, *jede einzelne*
Telemetrie-Option in einer neuen Software bewusst zu prüfen, statt
Defaults blind zu übernehmen. Bei n8n ist die Doku gut – bei vielen anderen
Tools muss man im Source Code danach suchen.

## Encryption-Key-Verlust = Datenverlust

Die n8n-Credentials (API-Keys etc.) sind mit `N8N_ENCRYPTION_KEY`
verschlüsselt gespeichert. Wer den Key verliert (z. B. weil der Server
gelöscht wird, ohne `.env` lokal zu sichern), verliert alle Credentials
unwiderruflich.

Praktisch: vor dem Server-Delete `.env` per `scp` lokal sichern – siehe
[server-loeschen.md](server-loeschen.md).

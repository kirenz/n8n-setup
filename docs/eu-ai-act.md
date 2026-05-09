# EU AI Act – Kontext für n8n-Workflows

Der EU AI Act (Verordnung (EU) 2024/1689) ist seit August 2024 in Kraft;
die meisten Pflichten gelten gestaffelt zwischen Februar 2025 und August
2027. Diese Notiz ist kein Rechtsgutachten – sie soll Studierenden helfen,
die Risiko-Logik des Acts auf typische n8n-Workflows zu übertragen.

## Kernpunkt: Use Case statt Tool

Der AI Act reguliert **wofür** ein KI-System eingesetzt wird, nicht
welches Tool dahintersteht. n8n als Plattform ist „neutral"; ein Workflow,
der OpenAI nutzt, kann verboten oder erlaubt sein – je nach Use Case.

## Die vier Risikoklassen

### 1. Verbotene Praktiken (Art. 5)

Gilt seit Februar 2025. Beispiele für **n8n-Workflows, die nicht gebaut
werden dürfen**:

- Social Scoring von Bürgerinnen und Bürgern
- Emotionserkennung am Arbeitsplatz oder in Bildungseinrichtungen
- Predictive Policing rein auf Profilbasis
- Manipulative Systeme, die Schwächen ausnutzen
  (z. B. ältere Menschen, Kinder)

→ in der Übung: Workflow-Ideen kritisch prüfen, ob sie in eine dieser
Kategorien fallen.

### 2. Hochrisiko-KI (Annex III)

Hier liegt der größte Teil der praktisch relevanten Pflichten. Beispiele,
die typischerweise in n8n gebaut werden:

| Annex-III-Kategorie         | Typischer n8n-Workflow                              |
| --------------------------- | ---------------------------------------------------- |
| Beschäftigung               | Recruiting-Scoring (Lebenslauf → Score)             |
| Beschäftigung               | Bewerbungs-Auswahl-Automation                       |
| Bildung                     | Automatisierte Bewertung von Klausuren/Aufgaben     |
| Zugang zu Diensten          | Kreditvergabe-Scoring, Versicherungs-Tarifierung    |
| Strafverfolgung             | Betrugs-Erkennung (mit Konsequenzen für Betroffene) |
| Migration und Asyl          | Risiko-Scoring für Anträge                          |
| Justiz und demokr. Prozesse | Vorhersagen über Gerichtsentscheidungen             |

Pflichten für Hochrisiko-Systeme (verkürzt):

- Risikomanagement-System
- Daten-Governance (Trainingsdaten, Bias-Prüfung)
- **Logging der Verarbeitung**
- Technische Dokumentation
- **Menschliche Aufsicht (Human Oversight)**
- Robustheit, Genauigkeit, Cybersicherheit
- Konformitätsbewertung vor Inverkehrbringen

### 3. Begrenztes Risiko – Transparenzpflichten

Workflows, die KI nutzen, ohne in Hochrisiko zu fallen, brauchen oft
Transparenz: Nutzer müssen erkennen können, dass sie mit KI interagieren.
Beispiele in n8n:

- Chatbot mit LLM → Nutzer informieren („Sie chatten mit einer KI")
- Generierte Bilder/Texte → kennzeichnen
- Deepfakes → transparent ausweisen

### 4. Minimales Risiko

Die Mehrheit der Workflows. Beispiele:

- Spam-Filterung
- Auto-Tagging eingehender E-Mails
- Newsletter-Personalisierung

Für diese Klasse gelten keine spezifischen AI-Act-Pflichten. DSGVO bleibt
selbstverständlich gültig.

## Logging-Pflicht und n8n-Execution-Log

Hochrisiko-Systeme müssen die Verarbeitungs-Schritte protokollieren. n8n
bringt das von Haus aus mit:

- Jede Workflow-Ausführung wird im Execution-Log gespeichert
- Inputs, Outputs, Fehler je Node sind nachvollziehbar
- Aufbewahrungsdauer in n8n konfigurierbar
  (`EXECUTIONS_DATA_PRUNE_MAX_AGE`)

Praktisch: für Hochrisiko-Workflows die Aufbewahrung des Execution-Logs
auf den nach AI Act geforderten Zeitraum hochsetzen (Art. 19: mindestens
6 Monate, sofern nicht anders geregelt).

## Human Oversight in n8n-Workflows

Hochrisiko-Workflows brauchen menschliche Aufsicht. n8n-Patterns dafür:

- **Approval-Step**: Slack/Teams-Notification, die per Klick weiterführt
  (Wait-Node mit Webhook-Resume)
- **Manual Review Queue**: Workflow speichert Vorschläge in einer
  Datenbank, ein Mensch entscheidet im UI über jeden Fall
- **Confidence Threshold**: nur eindeutige Fälle automatisch verarbeiten,
  Grenzfälle eskalieren

→ in der Übung: für einen typischen Hochrisiko-Workflow den
Human-Oversight-Punkt explizit in den Workflow einbauen.

## Generative-AI-Modelle (GPAI)

Anbieter von General-Purpose-AI-Modellen (OpenAI, Anthropic, Google,
Mistral …) tragen eigene Pflichten – Transparenz, Trainingsdaten-Summary,
Copyright-Konformität. Das betrifft die Modell-Anbieter, nicht direkt die
n8n-Nutzerin. Aber: bei besonders mächtigen Modellen mit „systemischem
Risiko" gibt es zusätzliche Anforderungen, die irgendwann auf den
Workflow durchschlagen können.

## Praktische Empfehlung für den Kurs

Vor jedem produktiven n8n-Workflow drei Fragen beantworten:

1. **Welcher Annex-III-Kategorie ähnelt der Use Case?**
   → wenn ja, Hochrisiko-Pflichten prüfen
2. **Erkennt der Nutzer, dass KI im Spiel ist?**
   → wenn nein, Transparenz nachrüsten
3. **Wo greift ein Mensch ein, wenn das Modell falsch liegt?**
   → konkreten Oversight-Punkt im Workflow markieren

## Weiterführend

- Volltext: [eur-lex.europa.eu](https://eur-lex.europa.eu) – Verordnung 2024/1689
- Annex III: Liste der Hochrisiko-Bereiche
- AI Office der EU-Kommission: zentrale Aufsichtsstelle

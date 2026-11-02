# Streamlit-App mit lokalen Modellen auf Hetzner betreiben (Anleitung für einen Coding-Agenten)

Diese Datei ist für einen Coding-Agenten geschrieben (Claude Code, Codex, Cursor oder vergleichbar), der auf dem Rechner der Entwicklerin läuft. Der Agent richtet eine Streamlit-App mit lokalen Sprachmodellen als Docker-Stack auf einem Hetzner-Cloud-Server ein, hinter HTTPS und Login. Die Entwicklerin bleibt Betreiberin des Servers.

Zielbild: Die App ist unter `https://<ip-mit-bindestrichen>.sslip.io` erreichbar, verlangt Benutzername und Passwort, und alle Daten bleiben auf dem Server in Deutschland. Kein Aufruf geht an externe KI-Anbieter.

Die Grundlagen (Hetzner, Docker Compose, Caddy, sslip.io) sind im Kurs [n8n einrichten](https://kirenz.github.io/n8n-setup/) erklärt, Kapitel [Hetzner](https://kirenz.github.io/n8n-setup/hetzner/). Diese Anleitung ersetzt n8n durch die Streamlit-App und ergänzt Ollama für die Modelle und einen Login in Caddy.

## Rollen

**Die Entwicklerin** erledigt vorab, was ein Konto oder eine Unterschrift braucht:

1. Konto bei [console.hetzner.cloud](https://console.hetzner.cloud) anlegen und Zahlungsmittel hinterlegen.
2. Auftragsverarbeitungsvertrag (AVV) in der Console unter Konto, Rechtliches, abschließen.
3. In der Console ein Projekt anlegen (zum Beispiel `content-engine`) und darin unter Sicherheit, API-Tokens, einen Token mit Lese- und Schreibrechten erzeugen. Den Token dem Agenten über eine Umgebungsvariable `HCLOUD_TOKEN` geben, nicht im Chat und nicht in einer Datei im Repo.
4. Festlegen, welche Modelle die App braucht (Name und Größe) und welche Unternehmen Zugang bekommen.

**Der Agent** erledigt alle Schritte unten. Er legt den Server per `hcloud`-CLI an, baut den Stack und prüft ihn. Er stoppt und fragt nach, wenn ein Schritt Geld kostet, das über die hier genannte Größenordnung hinausgeht (etwa 30 bis 40 € im Monat), oder wenn Unternehmensdaten ins Spiel kommen.

## Leitplanken

- Geheimnisse (`.env`, Passwörter, API-Token, Hashes) stehen in keinem Commit. `.env` gehört in `.gitignore`. Prüfe das, bevor du zum ersten Mal committest.
- Alle Modellaufrufe laufen gegen Ollama auf dem Server. Wenn die App irgendwo einen externen API-Key (OpenAI, Anthropic, Google) erwartet, halte an und berichte, statt ihn zu setzen.
- Der Server hat keine GPU. Modelle laufen auf der CPU, also langsam. Wähle den Server nach dem Speicherbedarf der Modelle (Abschnitt Servergröße). Wenn die Antwortzeit für die Nutzung unbrauchbar ist, berichte das mit Messwerten, und schlage ein kleineres Modell vor.
- Zugang für Unternehmen erst nach deren schriftlicher Zustimmung. Bis dahin arbeitet nur die Entwicklerin mit der App.
- Nach der Evaluation wird der Server gelöscht (Abschnitt Abbau). Vorher Daten sichern.

## Schritt 1: App containerfähig machen

Arbeite im Repo der Streamlit-App.

1. Lies die App und stelle fest, wie sie Modelle lädt:
   - Über Ollama (Python-Paket `ollama` oder HTTP auf Port 11434): Weiter mit Ollama als eigenem Container. Die App spricht Ollama über die Umgebungsvariable `OLLAMA_HOST=http://ollama:11434` an. Ersetze fest kodierte `localhost`-Adressen durch diese Variable.
   - Über `transformers`, `sentence-transformers` oder Ähnliches direkt in Python: Kein Ollama nötig. Lege die Modelle in ein Volume (`HF_HOME=/models`), damit der Download den Container-Neustart überlebt.
2. Lege `requirements.txt` an oder prüfe sie: nur die Pakete, die die App importiert, mit festen Versionen (`pip freeze` aus der laufenden lokalen Umgebung als Basis).
3. Lege `.streamlit/config.toml` an:

   ```toml
   [server]
   headless = true
   address = "0.0.0.0"
   port = 8501
   enableXsrfProtection = true

   [browser]
   gatherUsageStats = false
   ```

4. Lege `Dockerfile` an:

   ```dockerfile
   FROM python:3.12-slim
   WORKDIR /app
   COPY requirements.txt .
   RUN pip install --no-cache-dir -r requirements.txt
   COPY . .
   EXPOSE 8501
   HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8501/_stcore/health')"
   CMD ["streamlit", "run", "app.py"]
   ```

   Ersetze `app.py` durch die tatsächliche Startdatei.
5. Lege `.dockerignore` an mit `.git`, `.venv`, `venv`, `__pycache__`, `.env`, `data/` und allem, was Unternehmensdaten oder lokale Modelldateien enthält.

Fertig, wenn `docker build -t content-engine .` lokal ohne Fehler durchläuft.

## Schritt 2: Stack definieren

Lege im Repo einen Ordner `deploy/` an mit drei Dateien.

`deploy/docker-compose.yml`:

```yaml
services:
  app:
    build: ..
    restart: unless-stopped
    env_file: .env
    environment:
      OLLAMA_HOST: http://ollama:11434
    depends_on:
      - ollama
    networks: [internal]

  ollama:
    image: ollama/ollama:latest
    restart: unless-stopped
    volumes:
      - ollama_models:/root/.ollama
    networks: [internal]

  caddy:
    image: caddy:2.11.7-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      DOMAIN: ${DOMAIN}
      BASIC_AUTH_USER: ${BASIC_AUTH_USER}
      BASIC_AUTH_HASH: ${BASIC_AUTH_HASH}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - app
    networks: [internal]

networks:
  internal:

volumes:
  ollama_models:
  caddy_data:
  caddy_config:
```

Nur Caddy veröffentlicht Ports. App und Ollama sind von außen nicht erreichbar. Lass den Ollama-Dienst weg, wenn die App ihre Modelle direkt in Python lädt; hänge dann stattdessen ein Volume `models:/models` an `app` und setze `HF_HOME=/models`.

`deploy/Caddyfile`:

```
{$DOMAIN} {
	header Strict-Transport-Security "max-age=31536000"

	basic_auth {
		{$BASIC_AUTH_USER} {$BASIC_AUTH_HASH}
	}

	reverse_proxy app:8501
}
```

Caddy holt das Let's-Encrypt-Zertifikat selbst. `basic_auth` schützt die ganze App, auch die WebSocket-Verbindung von Streamlit.

`deploy/.env.example`:

```
DOMAIN=__DOMAIN__
BASIC_AUTH_USER=content-engine
# bcrypt-Hash, erzeugt mit: docker run --rm caddy:2.11.7-alpine caddy hash-password --plaintext '<passwort>'
# In einfachen Anführungszeichen lassen: Docker Compose interpretiert sonst die $-Zeichen im Hash.
BASIC_AUTH_HASH='__BASIC_AUTH_HASH__'
```

Trage `deploy/.env` in `.gitignore` ein.

Fertig, wenn der Stack lokal läuft: Lege dafür eine lokale `deploy/.env` mit `DOMAIN=localhost` an, starte `docker compose -f deploy/docker-compose.yml up --build`, und prüfe, dass `https://localhost` nach Login die App zeigt (das lokale Zertifikat ist selbstsigniert, die Browserwarnung ist hier erwartet). Lade einmal ein Modell mit `docker compose -f deploy/docker-compose.yml exec ollama ollama pull <modell>` und stelle sicher, dass die App damit antwortet.

## Schritt 3: Servergröße bestimmen

Rechne vor dem Anlegen:

- Arbeitsspeicher: Summe der Modellgrößen (die Dateigröße der quantisierten Modelle, bei Ollama `ollama list`) plus 3 GB für Betriebssystem, App und Caddy. Ein 7B-Modell in 4-Bit-Quantisierung braucht etwa 5 GB.
- Für ein einzelnes 7B-Modell reichen 16 GB RAM. Für ein 3B-Modell reichen 8 GB.
- Mehr vCPU bedeutet schnellere Antworten. Nimm die Variante mit den meisten Kernen in der gewählten RAM-Klasse.

Die aktuellen Typnamen und Preise zeigt `hcloud server-type list`. Lege dich auf einen Typ fest und nenne der Entwicklerin den Monatspreis, bevor du Schritt 4 ausführst.

## Schritt 4: Server anlegen

Voraussetzung: `HCLOUD_TOKEN` ist in der Umgebung gesetzt, ein SSH-Schlüssel liegt unter `~/.ssh/id_ed25519.pub` (sonst mit `ssh-keygen -t ed25519` erzeugen).

1. Installiere die Hetzner-CLI (`brew install hcloud` auf macOS, sonst siehe [github.com/hetznercloud/cli](https://github.com/hetznercloud/cli)). Prüfe mit `hcloud server-type list`, dass der Token funktioniert.
2. Lege `deploy/cloud-init.yaml` an:

   ```yaml
   #cloud-config
   package_update: true
   package_upgrade: true
   packages:
     - docker.io
     - docker-compose-v2
     - ufw
     - rsync
   runcmd:
     - systemctl enable --now docker
     - ufw default deny incoming
     - ufw default allow outgoing
     - ufw allow 22/tcp
     - ufw allow 80/tcp
     - ufw allow 443/tcp
     - ufw --force enable
   ```

3. Lege SSH-Schlüssel, Firewall und Server an:

   ```bash
   hcloud ssh-key create --name content-engine --public-key-from-file ~/.ssh/id_ed25519.pub
   hcloud firewall create --name content-engine-fw
   for p in 22 80 443; do
     hcloud firewall add-rule content-engine-fw --direction in --protocol tcp --port $p --source-ips 0.0.0.0/0 --source-ips ::/0
   done
   hcloud server create --name content-engine --type <typ-aus-schritt-3> --image ubuntu-24.04 \
     --location nbg1 --ssh-key content-engine --firewall content-engine-fw \
     --user-data-from-file deploy/cloud-init.yaml
   ```

   `nbg1` ist Nürnberg, `fsn1` Falkenstein. Beide liegen in Deutschland.
4. Lies die IP mit `hcloud server ip content-engine` und warte, bis `ssh root@<ip> cloud-init status --wait` mit `done` endet (etwa drei Minuten).

Fertig, wenn `ssh root@<ip> docker compose version` eine Version ausgibt und `ssh root@<ip> ufw status` die drei Ports zeigt.

## Schritt 5: Stack auf den Server bringen

1. Bilde die Domain aus der IP: Punkte durch Bindestriche ersetzen und `.sslip.io` anhängen. Aus `1.2.3.4` wird `1-2-3-4.sslip.io`.
2. Erzeuge ein Passwort (`openssl rand -base64 18`) und den Hash dazu (`docker run --rm caddy:2.11.7-alpine caddy hash-password --plaintext '<passwort>'`).
3. Kopiere das Repo ohne lokale Daten auf den Server:

   ```bash
   rsync -az --exclude-from=.dockerignore --exclude .git ./ root@<ip>:/opt/content-engine/
   ```

4. Schreibe `/opt/content-engine/deploy/.env` auf dem Server mit `DOMAIN`, `BASIC_AUTH_USER` und `BASIC_AUTH_HASH` (Hash in einfachen Anführungszeichen) und setze `chmod 600`.
5. Starte den Stack und lade die Modelle:

   ```bash
   ssh root@<ip> 'cd /opt/content-engine/deploy && docker compose up -d --build'
   ssh root@<ip> 'cd /opt/content-engine/deploy && docker compose exec ollama ollama pull <modell>'
   ```

6. Prüfe von außen:

   ```bash
   curl -sI https://<domain> | head -1                     # erwartet: HTTP/2 401
   curl -sI -u content-engine:'<passwort>' https://<domain> | head -1   # erwartet: HTTP/2 200
   ```

7. Miss eine typische Anfrage der App einmal durch (Zeit bis zur vollständigen Antwort) und notiere den Wert für die Übergabe.

Fertig, wenn beide `curl`-Aufrufe die erwarteten Statuscodes liefern und die App im Browser nach Login eine Modellantwort erzeugt.

## Schritt 6: Übergabe

Lege lokal, außerhalb des Repos, eine Datei `ZUGANG-content-engine.md` an, mit: URL, Benutzername, Passwort, Server-IP, Servertyp und Monatspreis, Antwortzeit aus Schritt 5, und den drei Betriebsbefehlen (`docker compose ps`, `docker compose logs -f app`, `docker compose up -d --build` nach Änderungen). Übergib der Entwicklerin den Pfad. Das Passwort erscheint nirgends sonst, auch nicht im Chatverlauf.

Für Updates der App genügen danach Schritt 5.3 und `docker compose up -d --build`.

## Abbau nach der Evaluation

1. Daten sichern, die in der App entstanden sind (Volumes oder Exportfunktion der App, je nach Aufbau).
2. `hcloud server delete content-engine`, danach `hcloud firewall delete content-engine-fw`.
3. In der Hetzner-Console prüfen, dass keine Ressource mehr läuft, sonst läuft die Abrechnung weiter.

## Fehlerdiagnose

| Symptom | Wahrscheinliche Ursache | Nächster Schritt |
|---|---|---|
| `curl` liefert keine Antwort | Caddy läuft nicht oder Zertifikat fehlt noch | `docker compose logs caddy --tail 50`; bei Rate-Limit von Let's Encrypt Domain auf `nip.io` umstellen |
| 502 Bad Gateway | App-Container gestartet, Streamlit noch nicht bereit oder abgestürzt | `docker compose logs app --tail 100` |
| Login wird nie akzeptiert | Hash in `.env` ohne einfache Anführungszeichen, Compose hat `$` ersetzt | `.env` korrigieren, `docker compose up -d` |
| App meldet Verbindung zu `localhost:11434` verweigert | App nutzt nicht `OLLAMA_HOST` | Aufruf in der App auf die Umgebungsvariable umstellen |
| Container `ollama` wird beendet (OOM) | Modell größer als der Arbeitsspeicher | kleineres Modell oder größeren Servertyp (`hcloud server change-type`) |
| Antwort dauert Minuten | Modell zu groß für CPU-Betrieb | kleineres oder stärker quantisiertes Modell, Messwert berichten |

# 🔌 Waveshare Relay Hat Controller

Eine Python-WebApp zur Steuerung von drei Relais des Waveshare Relay Hats auf einem Raspberry Pi 4. Unterstützt sowohl Web-Interface als auch Webhook-API.

## Features

*   ✨ Modernes Web-Interface mit Echtzeit-Status
*   🔘 Individuelle Steuerung aller drei Relais
*   🔄 Toggle-Funktion zum Umschalten
*   🛑 "Alle Aus"-Funktion
*   🌐 REST-API für Webhooks und Automatisierung
*   📊 Echtzeit-Statusanzeige
*   📱 Responsive Design (funktioniert auf Desktop & Mobile)

## Voraussetzungen

*   Raspberry Pi 4 (oder ähnlich)
*   Waveshare Relay Hat
*   Python 3.7 oder höher
*   Raspbian/Raspberry Pi OS

## Installation

### 1\. Repository klonen

```
cd /home/pi
git clone <dein-repo-url> magnetrelease
cd magnetrelease
```

### 2\. Python Virtual Environment erstellen

```
python3 -m venv venv
source venv/bin/activate
```

### 3\. Abhängigkeiten installieren

```
pip install -r requirements.txt
```

### 4\. GPIO-Berechtigungen

Stelle sicher, dass dein Benutzer Mitglied der `gpio`\-Gruppe ist:

```
sudo usermod -a -G gpio $USER
```

Nach dieser Änderung musst du dich neu anmelden oder den Raspberry Pi neu starten.

## Verwendung

### Manueller Start

```
source venv/bin/activate
python app.py
```

Die Anwendung läuft dann auf `http://<raspberry-pi-ip>:5000`

### Automatischer Start mit systemd

Erstelle eine Systemd-Service-Datei:

```
sudo nano /etc/systemd/system/relay-controller.service
```

Füge folgenden Inhalt ein (passe die Pfade an):

```
[Unit]
Description=Waveshare Relay Hat Controller
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/magnetrelease
Environment="PATH=/home/pi/magnetrelease/venv/bin"
ExecStart=/home/pi/magnetrelease/venv/bin/python /home/pi/magnetrelease/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Service aktivieren und starten:

```
sudo systemctl daemon-reload
sudo systemctl enable relay-controller.service
sudo systemctl start relay-controller.service
```

Status überprüfen:

```
sudo systemctl status relay-controller.service
```

Logs anzeigen:

```
sudo journalctl -u relay-controller.service -f
```

## GPIO-Pin-Belegung

Das Waveshare Relay Hat verwendet folgende GPIO-Pins:

*   **Relay 1**: GPIO 26
*   **Relay 2**: GPIO 20
*   **Relay 3**: GPIO 21

Die Relais sind **aktiv LOW** (LOW = Ein, HIGH = Aus).

## Web-Interface

Öffne einen Browser und navigiere zu:

```
http://<raspberry-pi-ip>:5000
```

### Features:

*   **Ein/Aus-Buttons**: Schaltet das jeweilige Relay direkt ein oder aus
*   **Toggle-Button**: Wechselt den aktuellen Zustand
*   **Alle Aus**: Schaltet alle drei Relais gleichzeitig aus
*   **Statusanzeige**: Echtzeit-Anzeige mit grünem (Ein) / rotem (Aus) Indikator

## API-Endpoints

### Einzelnes Relay steuern

#### Relay einschalten

```
POST /api/relay/<relay_num>/on
```

Beispiel:

```
curl -X POST http://192.168.1.100:5000/api/relay/1/on
```

#### Relay ausschalten

```
POST /api/relay/<relay_num>/off
```

Beispiel:

```
curl -X POST http://192.168.1.100:5000/api/relay/2/off
```

#### Relay umschalten

```
POST /api/relay/<relay_num>/toggle
```

Beispiel:

```
curl -X POST http://192.168.1.100:5000/api/relay/3/toggle
```

### Status abfragen

#### Status eines einzelnen Relays

```
GET /api/relay/<relay_num>/state
```

Beispiel:

```
curl http://192.168.1.100:5000/api/relay/1/state
```

Antwort:

```
{
  "success": true,
  "relay": 1,
  "state": true
}
```

#### Status aller Relais

```
GET /api/relay/all/state
```

Beispiel:

```
curl http://192.168.1.100:5000/api/relay/all/state
```

Antwort:

```
{
  "success": true,
  "relays": [
    {"relay": 1, "state": true, "pin": 26},
    {"relay": 2, "state": false, "pin": 20},
    {"relay": 3, "state": false, "pin": 21}
  ]
}
```

### Alle Relais ausschalten

```
POST /api/relay/all/off
```

Beispiel:

```
curl -X POST http://192.168.1.100:5000/api/relay/all/off
```

### Generischer Webhook-Endpoint

Für Automatisierungsplattformen wie IFTTT, Home Assistant, Node-RED, etc.

```
POST /api/webhook
Content-Type: application/json

{
  "relay": 1,
  "action": "on"
}
```

**Mögliche Actions**: `on`, `off`, `toggle`

Beispiele:

```
# Relay 1 einschalten
curl -X POST http://192.168.1.100:5000/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"relay": 1, "action": "on"}'

# Relay 2 ausschalten
curl -X POST http://192.168.1.100:5000/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"relay": 2, "action": "off"}'

# Relay 3 umschalten
curl -X POST http://192.168.1.100:5000/api/webhook \
  -H "Content-Type: application/json" \
  -d '{"relay": 3, "action": "toggle"}'
```

## Integration mit Home Assistant

Beispiel-Konfiguration für `configuration.yaml`:

```
switch:
  - platform: rest
    name: "Magnet Relay 1"
    resource: http://192.168.1.100:5000/api/relay/1/toggle
    state_resource: http://192.168.1.100:5000/api/relay/1/state
    body_on: '{}'
    body_off: '{}'
    is_on_template: '{{ value_json.state }}'
    headers:
      Content-Type: application/json
      
  - platform: rest
    name: "Magnet Relay 2"
    resource: http://192.168.1.100:5000/api/relay/2/toggle
    state_resource: http://192.168.1.100:5000/api/relay/2/state
    body_on: '{}'
    body_off: '{}'
    is_on_template: '{{ value_json.state }}'
    headers:
      Content-Type: application/json
```

## Sicherheitshinweise

⚠️ **Wichtig**: Diese Anwendung hat keine Authentifizierung!

Für den Produktivbetrieb solltest du:

*   Eine Firewall einrichten und nur bestimmte IPs zulassen
*   Einen Reverse Proxy mit Basic Auth verwenden (z.B. nginx)
*   Die Anwendung nur im lokalen Netzwerk betreiben
*   Bei Bedarf HTTPS einrichten

## Anpassungen

### GPIO-Pins ändern

Öffne `app.py` und ändere die Pin-Belegung in `RELAY_PINS`:

```python
RELAY_PINS = {
    1: 26,  # Dein Pin für Relay 1
    2: 20,  # Dein Pin für Relay 2
    3: 21   # Dein Pin für Relay 3
}
```

### Port ändern

Ändere den Port in `app.py` (Standard: 5000):

```python
app.run(host='0.0.0.0', port=8080, debug=False)
```

## Fehlerbehebung

### GPIO-Fehler

```
RuntimeError: No access to /dev/mem. Try running as root!
```

**Lösung**: Benutzer zur gpio-Gruppe hinzufügen:

```
sudo usermod -a -G gpio $USER
```

### Port bereits belegt

```
OSError: [Errno 98] Address already in use
```

**Lösung**: Ändere den Port in `app.py` oder beende den anderen Prozess:

```
sudo lsof -i :5000
sudo kill -9 <PID>
```

### Relais reagieren nicht

Überprüfe:

1.  Waveshare Relay Hat ist korrekt aufgesteckt
2.  GPIO-Pins sind korrekt konfiguriert
3.  Stromversorgung ist ausreichend

## Lizenz

Siehe [LICENSE](LICENSE)

## Autor

Erstellt für die Steuerung von Waveshare Relay Hats auf Raspberry Pi.
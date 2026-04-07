#!/bin/bash
# Installationsskript für Waveshare Relay Hat Controller

set -e  # Bei Fehler abbrechen

echo "======================================"
echo "  Relay Controller Installation"
echo "======================================"
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Überprüfen ob als root ausgeführt wird
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Bitte nicht als root ausführen!${NC}"
    echo "Führe das Skript als normaler Benutzer aus (z.B. pi)"
    exit 1
fi

# Python3 überprüfen
echo -e "${YELLOW}[1/6]${NC} Überprüfe Python-Installation..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 ist nicht installiert!${NC}"
    echo "Installiere mit: sudo apt-get install python3 python3-pip python3-venv"
    exit 1
fi
echo -e "${GREEN}✓${NC} Python3 gefunden: $(python3 --version)"

# GPIO-Gruppe überprüfen
echo -e "${YELLOW}[2/6]${NC} Überprüfe GPIO-Berechtigungen..."
if groups $USER | grep -q gpio; then
    echo -e "${GREEN}✓${NC} Benutzer $USER ist bereits in der gpio-Gruppe"
else
    echo -e "${YELLOW}!${NC} Füge Benutzer zur gpio-Gruppe hinzu..."
    sudo usermod -a -G gpio $USER
    echo -e "${GREEN}✓${NC} Benutzer hinzugefügt. ${RED}Bitte neu anmelden oder Pi neu starten!${NC}"
fi

# Virtual Environment erstellen
echo -e "${YELLOW}[3/6]${NC} Erstelle Virtual Environment..."
if [ -d "venv" ]; then
    echo -e "${YELLOW}!${NC} venv existiert bereits, überspringe..."
else
    python3 -m venv venv
    echo -e "${GREEN}✓${NC} Virtual Environment erstellt"
fi

# Dependencies installieren
echo -e "${YELLOW}[4/6]${NC} Installiere Python-Abhängigkeiten..."
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
echo -e "${GREEN}✓${NC} Abhängigkeiten installiert"

# Systemd Service einrichten
echo -e "${YELLOW}[5/6]${NC} Systemd-Service konfigurieren..."
read -p "Möchtest du den Service für automatischen Start einrichten? (j/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[JjYy]$ ]]; then
    # Pfade in der Service-Datei anpassen
    CURRENT_DIR=$(pwd)
    CURRENT_USER=$(whoami)
    
    # Temporäre Service-Datei mit aktuellen Pfaden erstellen
    sed -e "s|/home/pi/magnetrelease|$CURRENT_DIR|g" \
        -e "s|User=pi|User=$CURRENT_USER|g" \
        relay-controller.service > /tmp/relay-controller.service
    
    sudo cp /tmp/relay-controller.service /etc/systemd/system/relay-controller.service
    sudo systemctl daemon-reload
    sudo systemctl enable relay-controller.service
    
    read -p "Service jetzt starten? (j/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[JjYy]$ ]]; then
        sudo systemctl start relay-controller.service
        echo -e "${GREEN}✓${NC} Service gestartet"
        sleep 2
        sudo systemctl status relay-controller.service --no-pager
    else
        echo "Service kann später mit 'sudo systemctl start relay-controller.service' gestartet werden"
    fi
    
    echo -e "${GREEN}✓${NC} Service installiert und aktiviert"
else
    echo "Service-Installation übersprungen"
fi

# Abschluss
echo ""
echo -e "${YELLOW}[6/6]${NC} Installation abgeschlossen!"
echo ""
echo "======================================"
echo -e "${GREEN}  Installation erfolgreich!${NC}"
echo "======================================"
echo ""
echo "Nächste Schritte:"
echo ""
echo "1. Manueller Start:"
echo "   source venv/bin/activate"
echo "   python app.py"
echo ""
echo "2. Service-Befehle:"
echo "   sudo systemctl status relay-controller.service"
echo "   sudo systemctl start relay-controller.service"
echo "   sudo systemctl stop relay-controller.service"
echo "   sudo systemctl restart relay-controller.service"
echo "   sudo journalctl -u relay-controller.service -f"
echo ""
echo "3. Web-Interface öffnen:"
echo "   http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "Dokumentation: siehe README.md"
echo ""

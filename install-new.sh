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

# Benutzer bestimmen (root oder regulärer Benutzer)
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}Script wird als root ausgeführt${NC}"
    read -p "Für welchen Benutzer soll installiert werden? [pi]: " TARGET_USER
    TARGET_USER=${TARGET_USER:-pi}
    
    # Prüfen ob Benutzer existiert
    if ! id "$TARGET_USER" &>/dev/null; then
        echo -e "${RED}Benutzer '$TARGET_USER' existiert nicht!${NC}"
        exit 1
    fi
    
    INSTALL_USER="$TARGET_USER"
    USE_SUDO=""
    echo -e "${GREEN}✓${NC} Installation für Benutzer: $INSTALL_USER"
else
    INSTALL_USER="$USER"
    USE_SUDO="sudo"
    echo -e "${GREEN}✓${NC} Installation für aktuellen Benutzer: $INSTALL_USER"
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
if groups $INSTALL_USER | grep -q gpio; then
    echo -e "${GREEN}✓${NC} Benutzer $INSTALL_USER ist bereits in der gpio-Gruppe"
else
    echo -e "${YELLOW}!${NC} Füge Benutzer zur gpio-Gruppe hinzu..."
    if [ "$EUID" -eq 0 ]; then
        usermod -a -G gpio $INSTALL_USER
    else
        sudo usermod -a -G gpio $INSTALL_USER
    fi
    echo -e "${GREEN}✓${NC} Benutzer hinzugefügt. ${RED}Bitte neu anmelden oder Pi neu starten!${NC}"
fi

# Virtual Environment erstellen
echo -e "${YELLOW}[3/6]${NC} Erstelle Virtual Environment..."
if [ -d "venv" ]; then
    echo -e "${YELLOW}!${NC} venv existiert bereits, überspringe..."
else
    if [ "$EUID" -eq 0 ]; then
        # Als root: für Zielbenutzer erstellen
        sudo -u $INSTALL_USER python3 -m venv venv
        chown -R $INSTALL_USER:$INSTALL_USER venv
    else
        python3 -m venv venv
    fi
    echo -e "${GREEN}✓${NC} Virtual Environment erstellt"
fi

# Dependencies installieren
echo -e "${YELLOW}[4/6]${NC} Installiere Python-Abhängigkeiten..."
if [ "$EUID" -eq 0 ]; then
    # Als root für Zielbenutzer installieren
    sudo -u $INSTALL_USER bash -c "source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
else
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
fi
echo -e "${GREEN}✓${NC} Abhängigkeiten installiert"

# Systemd Service einrichten
echo -e "${YELLOW}[5/6]${NC} Systemd-Service konfigurieren..."
read -p "Möchtest du den Service für automatischen Start einrichten? (j/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[JjYy]$ ]]; then
    # Pfade in der Service-Datei anpassen
    CURRENT_DIR=$(pwd)
    
    # Temporäre Service-Datei mit aktuellen Pfaden erstellen
    sed -e "s|/home/pi/magnetrelease|$CURRENT_DIR|g" \
        -e "s|User=pi|User=$INSTALL_USER|g" \
        relay-controller.service > /tmp/relay-controller.service
    
    if [ "$EUID" -eq 0 ]; then
        cp /tmp/relay-controller.service /etc/systemd/system/relay-controller.service
        systemctl daemon-reload
        systemctl enable relay-controller.service
    else
        sudo cp /tmp/relay-controller.service /etc/systemd/system/relay-controller.service
        sudo systemctl daemon-reload
        sudo systemctl enable relay-controller.service
    fi
    
    read -p "Service jetzt starten? (j/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[JjYy]$ ]]; then
        if [ "$EUID" -eq 0 ]; then
            systemctl start relay-controller.service
            echo -e "${GREEN}✓${NC} Service gestartet"
            sleep 2
            systemctl status relay-controller.service --no-pager
        else
            sudo systemctl start relay-controller.service
            echo -e "${GREEN}✓${NC} Service gestartet"
            sleep 2
            sudo systemctl status relay-controller.service --no-pager
        fi
    else
        echo "Service kann später mit '${USE_SUDO} systemctl start relay-controller.service' gestartet werden"
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
echo "   ${USE_SUDO} systemctl status relay-controller.service"
echo "   ${USE_SUDO} systemctl start relay-controller.service"
echo "   ${USE_SUDO} systemctl stop relay-controller.service"
echo "   ${USE_SUDO} systemctl restart relay-controller.service"
echo "   ${USE_SUDO} journalctl -u relay-controller.service -f"
echo ""
echo "3. Web-Interface öffnen:"
echo "   http://$(hostname -I | awk '{print $1}'):5000"
echo ""
echo "Dokumentation: siehe README.md"
echo ""

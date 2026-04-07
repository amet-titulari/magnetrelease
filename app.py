#!/usr/bin/env python3
"""
Waveshare Relay Hat Controller
Web-Interface und Webhook-API zur Steuerung von drei Relais
"""
import os
from flask import Flask, render_template, jsonify, request
import RPi.GPIO as GPIO
import logging
from typing import Dict, Literal

# Logging konfigurieren
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# GPIO-Konfiguration für Waveshare Relay Hat
RELAY_PINS = {
    1: 26,  # Relay 1
    2: 20,  # Relay 2
    3: 21   # Relay 3
}

# Relay-Status speichern
relay_states: Dict[int, bool] = {1: False, 2: False, 3: False}


def setup_gpio():
    """GPIO-Pins initialisieren"""
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    
    for relay_num, pin in RELAY_PINS.items():
        GPIO.setup(pin, GPIO.OUT)
        GPIO.output(pin, GPIO.HIGH)  # HIGH = Aus (Relais sind aktiv LOW)
        relay_states[relay_num] = False
        logger.info(f"Relay {relay_num} (GPIO {pin}) initialisiert")


def cleanup_gpio():
    """GPIO aufräumen"""
    for pin in RELAY_PINS.values():
        GPIO.output(pin, GPIO.HIGH)  # Alle Relais ausschalten
    GPIO.cleanup()
    logger.info("GPIO bereinigt")


def set_relay(relay_num: int, state: bool) -> Dict:
    """
    Relay ein- oder ausschalten
    
    Args:
        relay_num: Relay-Nummer (1-3)
        state: True = Ein, False = Aus
    
    Returns:
        Status-Dictionary
    """
    if relay_num not in RELAY_PINS:
        return {"success": False, "error": f"Ungültige Relay-Nummer: {relay_num}"}
    
    pin = RELAY_PINS[relay_num]
    # Waveshare Relay Hat ist aktiv LOW
    gpio_state = GPIO.LOW if state else GPIO.HIGH
    GPIO.output(pin, gpio_state)
    relay_states[relay_num] = state
    
    status = "EIN" if state else "AUS"
    logger.info(f"Relay {relay_num} (GPIO {pin}) -> {status}")
    
    return {
        "success": True,
        "relay": relay_num,
        "state": state,
        "message": f"Relay {relay_num} ist jetzt {status}"
    }


def get_relay_state(relay_num: int) -> Dict:
    """Aktuellen Status eines Relays abfragen"""
    if relay_num not in RELAY_PINS:
        return {"success": False, "error": f"Ungültige Relay-Nummer: {relay_num}"}
    
    return {
        "success": True,
        "relay": relay_num,
        "state": relay_states[relay_num]
    }


@app.route('/')
def index():
    """Web-Interface anzeigen"""
    return render_template('index.html', relay_states=relay_states)


@app.route('/api/relay/<int:relay_num>/on', methods=['POST'])
def relay_on(relay_num: int):
    """Relay einschalten (Webhook-kompatibel)"""
    result = set_relay(relay_num, True)
    return jsonify(result), 200 if result["success"] else 400


@app.route('/api/relay/<int:relay_num>/off', methods=['POST'])
def relay_off(relay_num: int):
    """Relay ausschalten (Webhook-kompatibel)"""
    result = set_relay(relay_num, False)
    return jsonify(result), 200 if result["success"] else 400


@app.route('/api/relay/<int:relay_num>/toggle', methods=['POST'])
def relay_toggle(relay_num: int):
    """Relay umschalten"""
    if relay_num not in RELAY_PINS:
        return jsonify({"success": False, "error": f"Ungültige Relay-Nummer: {relay_num}"}), 400
    
    new_state = not relay_states[relay_num]
    result = set_relay(relay_num, new_state)
    return jsonify(result), 200 if result["success"] else 400


@app.route('/api/relay/<int:relay_num>/state', methods=['GET'])
def relay_state(relay_num: int):
    """Relay-Status abfragen"""
    result = get_relay_state(relay_num)
    return jsonify(result), 200 if result["success"] else 400


@app.route('/api/relay/all/state', methods=['GET'])
def all_relay_states():
    """Status aller Relais abfragen"""
    return jsonify({
        "success": True,
        "relays": [
            {"relay": num, "state": state, "pin": RELAY_PINS[num]}
            for num, state in relay_states.items()
        ]
    })


@app.route('/api/relay/all/off', methods=['POST'])
def all_relays_off():
    """Alle Relais ausschalten"""
    results = []
    for relay_num in RELAY_PINS.keys():
        result = set_relay(relay_num, False)
        results.append(result)
    
    return jsonify({
        "success": True,
        "message": "Alle Relais ausgeschaltet",
        "results": results
    })


@app.route('/api/webhook', methods=['POST'])
def webhook():
    """
    Generischer Webhook-Endpoint
    
    JSON Body Format:
    {
        "relay": 1,        # Relay-Nummer (1-3)
        "action": "on"     # "on", "off" oder "toggle"
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({"success": False, "error": "Kein JSON-Body"}), 400
        
        relay_num = data.get('relay')
        action = data.get('action', '').lower()
        
        if relay_num not in RELAY_PINS:
            return jsonify({"success": False, "error": f"Ungültige Relay-Nummer: {relay_num}"}), 400
        
        if action == 'on':
            result = set_relay(relay_num, True)
        elif action == 'off':
            result = set_relay(relay_num, False)
        elif action == 'toggle':
            new_state = not relay_states[relay_num]
            result = set_relay(relay_num, new_state)
        else:
            return jsonify({"success": False, "error": f"Ungültige Aktion: {action}"}), 400
        
        return jsonify(result), 200 if result["success"] else 400
        
    except Exception as e:
        logger.error(f"Webhook-Fehler: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500


if __name__ == '__main__':
    try:
        setup_gpio()
        # Server starten (von außen erreichbar auf Port 5000)
        app.run(host='0.0.0.0', port=5000, debug=False)
    except KeyboardInterrupt:
        logger.info("Server wird beendet...")
    finally:
        cleanup_gpio()

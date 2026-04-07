#!/usr/bin/env python3
"""
Test-Skript für Relay Controller (ohne echte Hardware)
Simuliert GPIO-Funktionalität für Entwicklung/Testing
"""
import sys
import time

# GPIO Mock für Testing ohne Hardware
class MockGPIO:
    BCM = "BCM"
    OUT = "OUT"
    HIGH = 1
    LOW = 0
    
    _pins = {}
    
    @classmethod
    def setmode(cls, mode):
        print(f"[GPIO Mock] Mode gesetzt: {mode}")
    
    @classmethod
    def setwarnings(cls, flag):
        print(f"[GPIO Mock] Warnings: {flag}")
    
    @classmethod
    def setup(cls, pin, mode):
        cls._pins[pin] = None
        print(f"[GPIO Mock] Pin {pin} als {mode} konfiguriert")
    
    @classmethod
    def output(cls, pin, state):
        cls._pins[pin] = state
        state_str = "LOW (Relay EIN)" if state == cls.LOW else "HIGH (Relay AUS)"
        print(f"[GPIO Mock] Pin {pin} -> {state_str}")
    
    @classmethod
    def cleanup(cls):
        print(f"[GPIO Mock] Cleanup - {len(cls._pins)} Pins gereinigt")
        cls._pins.clear()

# Mock GPIO importieren
sys.modules['RPi'] = type(sys)('RPi')
sys.modules['RPi.GPIO'] = MockGPIO

# Jetzt die echte App importieren
from app import app, setup_gpio, cleanup_gpio

if __name__ == '__main__':
    print("=" * 50)
    print("  Relay Controller - TEST MODE")
    print("  (Simuliert GPIO ohne echte Hardware)")
    print("=" * 50)
    print()
    
    try:
        setup_gpio()
        print()
        print("Server startet auf http://localhost:5000")
        print("Drücke Ctrl+C zum Beenden")
        print()
        app.run(host='127.0.0.1', port=5000, debug=True)
    except KeyboardInterrupt:
        print("\n\nServer wird beendet...")
    finally:
        cleanup_gpio()

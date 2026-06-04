#!/usr/bin/env python3
"""
NeXuS TTS Voice Tester
A GUI application to test different TTS engines and voices
"""

import sys
import subprocess
import re
from pathlib import Path

try:
    from PyQt6.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, 
                                QWidget, QComboBox, QTextEdit, QPushButton, QLabel, 
                                QSlider, QSpinBox, QGroupBox, QGridLayout, QPlainTextEdit)
    from PyQt6.QtCore import Qt, QThread, pyqtSignal
    from PyQt6.QtGui import QFont, QIcon
except ImportError:
    try:
        from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, 
                                    QWidget, QComboBox, QTextEdit, QPushButton, QLabel, 
                                    QSlider, QSpinBox, QGroupBox, QGridLayout, QPlainTextEdit)
        from PyQt5.QtCore import Qt, QThread, pyqtSignal
        from PyQt5.QtGui import QFont, QIcon
    except ImportError:
        print("❌ PyQt6 or PyQt5 required. Install with:")
        print("   doas apk add py3-pyqt6")
        print("   # or")
        print("   doas apk add py3-pyqt5")
        sys.exit(1)

class TTSEngine:
    def __init__(self, name, command_template, voice_lister=None):
        self.name = name
        self.command_template = command_template
        self.voice_lister = voice_lister
        self.voices = []
    
    def get_voices(self):
        """Get available voices for this engine"""
        if self.voice_lister:
            try:
                result = subprocess.run(self.voice_lister, shell=True, 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    return self.parse_voices(result.stdout)
            except:
                pass
        return ["default"]
    
    def parse_voices(self, output):
        """Parse voice list output - override in subclasses"""
        return ["default"]
    
    def speak(self, text, voice="default", rate=150, pitch=50):
        """Speak the text with given parameters"""
        try:
            cmd = self.command_template.format(
                text=f'"{text}"', 
                voice=voice, 
                rate=rate, 
                pitch=pitch
            )
            subprocess.run(cmd, shell=True, timeout=10)
            return True
        except:
            return False

class EspeakEngine(TTSEngine):
    def __init__(self):
        super().__init__(
            "eSpeak-NG", 
            "espeak-ng -v {voice} -s {rate} -p {pitch} {text}",
            "espeak-ng --voices"
        )
    
    def parse_voices(self, output):
        voices = ["default", "en", "en+f3", "en+m4"]
        for line in output.split('\n'):
            if line.strip() and not line.startswith('Pty'):
                parts = line.split()
                if len(parts) >= 2:
                    voice_name = parts[1]
                    if voice_name not in voices:
                        voices.append(voice_name)
        return voices

class MbrolaEngine(TTSEngine):
    def __init__(self):
        super().__init__(
            "MBROLA (High Quality)",
            "espeak-ng -v {voice} -s {rate} -p {pitch} {text}",
            None
        )
        # English MBROLA voices only
        self.voices = [
            "mb-en1 (British Male - Clear)",
            "mb-us1 (American Female - Natural)", 
            "mb-us2 (American Male - Deep)",
            "mb-us3 (American Male - Young)"
        ]
    
    def get_voices(self):
        """Get available English MBROLA voices"""
        available_voices = []
        test_voices = ["mb-en1", "mb-us1", "mb-us2", "mb-us3"]
        
        for voice in test_voices:
            try:
                # Test if voice is available
                result = subprocess.run(f"espeak-ng -v {voice} --stdout -t 'test' >/dev/null 2>&1", 
                                      shell=True, timeout=2)
                if result.returncode == 0:
                    if voice == "mb-en1":
                        available_voices.append("mb-en1 (British Male - Clear)")
                    elif voice == "mb-us1":
                        available_voices.append("mb-us1 (American Female - Natural)")
                    elif voice == "mb-us2":
                        available_voices.append("mb-us2 (American Male - Deep)")
                    elif voice == "mb-us3":
                        available_voices.append("mb-us3 (American Male - Young)")
            except:
                continue
        
        return available_voices if available_voices else ["No MBROLA voices found"]
    
    def speak(self, text, voice="mb-en1", rate=150, pitch=50):
        """Speak with MBROLA voice (extract voice name from description)"""
        # Extract actual voice name from description
        actual_voice = voice.split()[0] if " " in voice else voice
        
        try:
            cmd = f'espeak-ng -v {actual_voice} -s {rate} -p {pitch} "{text}"'
            subprocess.run(cmd, shell=True, timeout=10)
            return True
        except:
            return False

class FestivalEngine(TTSEngine):
    def __init__(self):
        super().__init__(
            "Festival",
            'echo {text} | festival --tts',
            None
        )
        self.voices = ["default", "kal_diphone", "rab_diphone", "don_diphone"]

class FliteEngine(TTSEngine):
    def __init__(self):
        super().__init__(
            "Flite",
            "flite -voice {voice} -t {text}",
            "flite -lv"
        )
        # Your specific voices with descriptions
        self.voices = [
            "rms (Male - Clear & Natural)",
            "slt (Female - Smooth & Pleasant)", 
            "awb (Male - Scottish Accent)",
            "kal (Male - Diphone)",
            "kal16 (Male - Diphone 16kHz)"
        ]
    
    def get_voices(self):
        """Get available Flite voices with descriptions"""
        # First try to detect available voices
        try:
            result = subprocess.run("flite -lv", shell=True, 
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                detected_voices = []
                for line in result.stdout.split('\n'):
                    if 'voice:' in line.lower():
                        voice = line.split()[-1]
                        # Add description if we know it
                        if voice == "rms":
                            detected_voices.append("rms (Male - Clear & Natural)")
                        elif voice == "slt":
                            detected_voices.append("slt (Female - Smooth & Pleasant)")
                        elif voice == "awb":
                            detected_voices.append("awb (Male - Scottish Accent)")
                        elif voice == "kal":
                            detected_voices.append("kal (Male - Diphone)")
                        elif voice == "kal16":
                            detected_voices.append("kal16 (Male - Diphone 16kHz)")
                        else:
                            detected_voices.append(voice)
                if detected_voices:
                    return detected_voices
        except:
            pass
        
        # Fallback to known voices
        return self.voices
    
    def speak(self, text, voice="rms", rate=150, pitch=50):
        """Speak with Flite voice (extract voice name from description)"""
        # Extract actual voice name from description
        actual_voice = voice.split()[0] if " " in voice else voice
        
        try:
            # Flite doesn't use rate/pitch the same way, but we can adjust
            cmd = f'flite -voice {actual_voice} -t "{text}"'
            subprocess.run(cmd, shell=True, timeout=10)
            return True
        except:
            return False

class SpeedDispatcherEngine(TTSEngine):
    def __init__(self):
        super().__init__(
            "Speech-Dispatcher",
            "spd-say -r {rate} -p {pitch} {text}",
            "spd-say -L"
        )

class TTSWorker(QThread):
    finished = pyqtSignal()
    error = pyqtSignal(str)
    
    def __init__(self, engine, text, voice, rate, pitch):
        super().__init__()
        self.engine = engine
        self.text = text
        self.voice = voice
        self.rate = rate
        self.pitch = pitch
    
    def run(self):
        try:
            success = self.engine.speak(self.text, self.voice, self.rate, self.pitch)
            if not success:
                self.error.emit("Failed to speak text")
        except Exception as e:
            self.error.emit(str(e))
        finally:
            self.finished.emit()

class TTSTestApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.engines = self.detect_engines()
        self.current_worker = None
        self.init_ui()
    
    def detect_engines(self):
        """Detect available TTS engines"""
        engines = []
        
        # Check for eSpeak-NG
        if self.command_exists("espeak-ng"):
            engines.append(EspeakEngine())
        
        # Check for MBROLA (high quality voices)
        if self.command_exists("espeak-ng") and self.command_exists("mbrola"):
            engines.append(MbrolaEngine())
        
        # Check for Festival
        if self.command_exists("festival"):
            engines.append(FestivalEngine())
        
        # Check for Flite
        if self.command_exists("flite"):
            engines.append(FliteEngine())
        
        # Check for Speech-Dispatcher
        if self.command_exists("spd-say"):
            engines.append(SpeedDispatcherEngine())
        
        return engines
    
    def command_exists(self, command):
        """Check if command exists"""
        try:
            subprocess.run([command, "--help"], stdout=subprocess.DEVNULL, 
                          stderr=subprocess.DEVNULL, timeout=2)
            return True
        except:
            return False
    
    def init_ui(self):
        self.setWindowTitle("🔥 NeXuS TTS Voice Tester")
        self.setGeometry(100, 100, 600, 500)
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        
        # Title
        title = QLabel("🎙️ NeXuS Text-to-Speech Tester")
        title.setFont(QFont("Arial", 16, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # Engine selection
        engine_group = QGroupBox("TTS Engine")
        engine_layout = QHBoxLayout(engine_group)
        
        self.engine_combo = QComboBox()
        for engine in self.engines:
            self.engine_combo.addItem(engine.name)
        self.engine_combo.currentTextChanged.connect(self.on_engine_changed)
        engine_layout.addWidget(QLabel("Engine:"))
        engine_layout.addWidget(self.engine_combo)
        
        layout.addWidget(engine_group)
        
        # Voice selection
        voice_group = QGroupBox("Voice Settings")
        voice_layout = QGridLayout(voice_group)
        
        self.voice_combo = QComboBox()
        voice_layout.addWidget(QLabel("Voice:"), 0, 0)
        voice_layout.addWidget(self.voice_combo, 0, 1)
        
        # Rate control
        voice_layout.addWidget(QLabel("Rate:"), 1, 0)
        self.rate_slider = QSlider(Qt.Orientation.Horizontal)
        self.rate_slider.setRange(50, 300)
        self.rate_slider.setValue(150)
        self.rate_spin = QSpinBox()
        self.rate_spin.setRange(50, 300)
        self.rate_spin.setValue(150)
        self.rate_slider.valueChanged.connect(self.rate_spin.setValue)
        self.rate_spin.valueChanged.connect(self.rate_slider.setValue)
        
        rate_layout = QHBoxLayout()
        rate_layout.addWidget(self.rate_slider)
        rate_layout.addWidget(self.rate_spin)
        voice_layout.addLayout(rate_layout, 1, 1)
        
        # Pitch control
        voice_layout.addWidget(QLabel("Pitch:"), 2, 0)
        self.pitch_slider = QSlider(Qt.Orientation.Horizontal)
        self.pitch_slider.setRange(0, 100)
        self.pitch_slider.setValue(50)
        self.pitch_spin = QSpinBox()
        self.pitch_spin.setRange(0, 100)
        self.pitch_spin.setValue(50)
        self.pitch_slider.valueChanged.connect(self.pitch_spin.setValue)
        self.pitch_spin.valueChanged.connect(self.pitch_slider.setValue)
        
        pitch_layout = QHBoxLayout()
        pitch_layout.addWidget(self.pitch_slider)
        pitch_layout.addWidget(self.pitch_spin)
        voice_layout.addLayout(pitch_layout, 2, 1)
        
        layout.addWidget(voice_group)
        
        # Text input
        text_group = QGroupBox("Text to Speak")
        text_layout = QVBoxLayout(text_group)
        
        self.text_input = QPlainTextEdit()
        self.text_input.setPlainText("Hello from NeXuS! This is a test of the text-to-speech system.")
        self.text_input.setMaximumHeight(100)
        text_layout.addWidget(self.text_input)
        
        layout.addWidget(text_group)
        
        # Buttons
        button_layout = QHBoxLayout()
        
        self.speak_button = QPushButton("🎙️ Speak")
        self.speak_button.clicked.connect(self.speak_text)
        button_layout.addWidget(self.speak_button)
        
        self.stop_button = QPushButton("⏹️ Stop")
        self.stop_button.clicked.connect(self.stop_speech)
        self.stop_button.setEnabled(False)
        button_layout.addWidget(self.stop_button)
        
        test_button = QPushButton("🧪 Test All Voices")
        test_button.clicked.connect(self.test_all_voices)
        button_layout.addWidget(test_button)
        
        layout.addWidget(QWidget())  # Spacer
        layout.addLayout(button_layout)
        
        # Status
        self.status_label = QLabel("Ready to test TTS voices")
        layout.addWidget(self.status_label)
        
        # Initialize
        if self.engines:
            self.on_engine_changed()
        else:
            self.status_label.setText("❌ No TTS engines found. Install espeak-ng, festival, or flite")
    
    def on_engine_changed(self):
        """Handle engine selection change"""
        if not self.engines:
            return
        
        engine_name = self.engine_combo.currentText()
        engine = next((e for e in self.engines if e.name == engine_name), None)
        
        if engine:
            self.voice_combo.clear()
            voices = engine.get_voices()
            self.voice_combo.addItems(voices)
            self.status_label.setText(f"Selected {engine_name} with {len(voices)} voices")
    
    def speak_text(self):
        """Speak the current text"""
        if not self.engines:
            return
        
        engine_name = self.engine_combo.currentText()
        engine = next((e for e in self.engines if e.name == engine_name), None)
        
        if not engine:
            return
        
        text = self.text_input.toPlainText().strip()
        if not text:
            self.status_label.setText("❌ Please enter some text to speak")
            return
        
        voice = self.voice_combo.currentText()
        rate = self.rate_spin.value()
        pitch = self.pitch_spin.value()
        
        self.speak_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        self.status_label.setText(f"🎙️ Speaking with {engine_name} - {voice}...")
        
        self.current_worker = TTSWorker(engine, text, voice, rate, pitch)
        self.current_worker.finished.connect(self.on_speech_finished)
        self.current_worker.error.connect(self.on_speech_error)
        self.current_worker.start()
    
    def stop_speech(self):
        """Stop current speech"""
        try:
            # Kill any running TTS processes with force
            subprocess.run(["pkill", "-9", "-f", "espeak"], stderr=subprocess.DEVNULL)
            subprocess.run(["pkill", "-9", "-f", "festival"], stderr=subprocess.DEVNULL)
            subprocess.run(["pkill", "-9", "-f", "flite"], stderr=subprocess.DEVNULL)
            subprocess.run(["pkill", "-9", "-f", "spd-say"], stderr=subprocess.DEVNULL)
            subprocess.run(["pkill", "-9", "-f", "mbrola"], stderr=subprocess.DEVNULL)
            
            # Alternative: mute audio temporarily
            subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "1"], 
                          stderr=subprocess.DEVNULL, timeout=1)
            subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"], 
                          stderr=subprocess.DEVNULL, timeout=1)
        except:
            pass
        
        if self.current_worker:
            self.current_worker.terminate()
            self.current_worker.wait(1000)  # Wait up to 1 second
        
        self.on_speech_finished()
    
    def on_speech_finished(self):
        """Handle speech completion"""
        self.speak_button.setEnabled(True)
        self.stop_button.setEnabled(False)
        self.status_label.setText("✅ Speech completed")
    
    def on_speech_error(self, error):
        """Handle speech error"""
        self.speak_button.setEnabled(True)
        self.stop_button.setEnabled(False)
        self.status_label.setText(f"❌ Error: {error}")
    
    def test_all_voices(self):
        """Test all available voices quickly"""
        if not self.engines:
            return
        
        engine_name = self.engine_combo.currentText()
        engine = next((e for e in self.engines if e.name == engine_name), None)
        
        if not engine:
            return
        
        voices = engine.get_voices()
        test_text = f"Testing voice"
        
        self.status_label.setText(f"🧪 Testing {len(voices)} voices...")
        
        for i, voice in enumerate(voices):
            try:
                engine.speak(f"{test_text} {i+1}", voice, 180, 50)
            except:
                continue
        
        self.status_label.setText(f"✅ Tested {len(voices)} voices")

def main():
    app = QApplication(sys.argv)
    app.setApplicationName("NeXuS TTS Tester")
    
    window = TTSTestApp()
    window.show()
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
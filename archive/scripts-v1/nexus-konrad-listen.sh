#!/bin/sh
# nexus-konrad-listen.sh
# Capture speaker output → faster-whisper → transcript file
# Usage: ./nexus-konrad-listen.sh
# Tail the transcript: tail -f /tmp/konrad-transcript.txt

MONITOR="alsa_output.usb-0c76_Gaming_Headset-00.iec958-stereo.monitor"
TRANSCRIPT="/tmp/konrad-transcript.txt"
CHUNK_SECS=5

# fallback to onboard if headset not active
pactl list short sources | grep -q "$MONITOR" || \
  MONITOR="alsa_output.pci-0000_00_1b.0.analog-stereo.monitor"

echo "=== NeXuS Konrad Listen ===" | tee "$TRANSCRIPT"
echo "Monitor: $MONITOR" | tee -a "$TRANSCRIPT"
echo "Transcript: $TRANSCRIPT" | tee -a "$TRANSCRIPT"
echo "---" | tee -a "$TRANSCRIPT"

parec --device="$MONITOR" \
      --format=s16le \
      --rate=16000 \
      --channels=1 | \
python3 - <<'EOF'
import sys, os, wave, tempfile, time

try:
    from faster_whisper import WhisperModel
except ImportError:
    print("ERROR: pip install faster-whisper", flush=True)
    sys.exit(1)

TRANSCRIPT = "/tmp/konrad-transcript.txt"
CHUNK_SECS = 5
RATE = 16000
SAMPWIDTH = 2
BYTES_PER_CHUNK = RATE * SAMPWIDTH * CHUNK_SECS

print("Loading model...", flush=True)
model = WhisperModel("base.en", device="cpu", compute_type="int8")
print("Listening...", flush=True)

buf = b""
while True:
    chunk = sys.stdin.buffer.read(4096)
    if not chunk:
        break
    buf += chunk
    if len(buf) >= BYTES_PER_CHUNK:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            tmpfile = f.name
            w = wave.open(f, "wb")
            w.setnchannels(1)
            w.setsampwidth(SAMPWIDTH)
            w.setframerate(RATE)
            w.writeframes(buf[:BYTES_PER_CHUNK])
            w.close()
        buf = buf[BYTES_PER_CHUNK:]
        segments, _ = model.transcribe(tmpfile, language="en", vad_filter=True)
        text = "".join(s.text for s in segments).strip()
        os.unlink(tmpfile)
        if text:
            line = f"[{time.strftime('%H:%M:%S')}] {text}"
            print(line, flush=True)
            with open(TRANSCRIPT, "a") as f:
                f.write(line + "\n")
EOF

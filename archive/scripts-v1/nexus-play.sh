#!/bin/sh
# nexus-play.sh — Media player for NeXuS Console
#
# kmscon runs with --no-drm (fbdev/pixman rendering), so it holds
# zero DRM master. mpv --vo=drm can take DRM master freely for full-quality
# hardware-accelerated video playback without any VT switch or compositor.
#
# Usage:
#   nexus-play video.mp4          # 🎬 full DRM video + VA-API hw decode
#   nexus-play -t video.mp4       # 📺 in-terminal true-color (--vo=tct)
#   nexus-play -a audio.mp3       # 🎵 audio only (PipeWire → sndio → ALSA fallback)
#   nexus-play --help

SCRIPT=$(basename "$0")

usage() {
    cat <<EOF
🎬 nexus-play — NeXuS Console media player

Usage: $SCRIPT [mode] <file> [mpv-options...]

Modes:
  (default)  Full DRM video — VA-API hw decode, kmscon holds no DRM master
  -t         In-terminal true-color video (--vo=tct), stays on current VT
  -a         Audio only via PipeWire, no video output
  -h|--help  Show this help

Examples:
  nexus-play movie.mp4
  nexus-play -t clip.mp4
  nexus-play -a podcast.mp3
  nexus-play movie.mp4 --volume=70 --loop

Requires:
  Video: user in 'video' group (you are: $(groups | tr ' ' '\n' | grep -c '^video$') ✓/✗)
  Audio: PipeWire preferred; falls back to sndio → ALSA automatically
EOF
}

MODE=drm
FILE=""

case "$1" in
    -h|--help) usage; exit 0 ;;
    -t) MODE=tct; shift ;;
    -a) MODE=audio; shift ;;
esac

if [ -z "$1" ]; then
    echo "❌ No file specified. Run: $SCRIPT --help"
    exit 1
fi

FILE="$1"; shift

if [ ! -f "$FILE" ]; then
    echo "❌ File not found: $FILE"
    exit 1
fi

case "$MODE" in
    drm)
        echo "🎬 Playing (DRM/VA-API): $(basename "$FILE")"
        mpv \
            --vo=drm \
            --hwdec=vaapi \
            --drm-connector=auto \
            --drm-mode=preferred \
            --ao=pipewire,sndio,alsa \
            --fs \
            "$@" \
            "$FILE"
        ;;
    tct)
        echo "📺 Playing (terminal): $(basename "$FILE")"
        mpv --vo=tct --ao=pipewire,sndio,alsa "$@" "$FILE"
        ;;
    audio)
        echo "🎵 Playing: $(basename "$FILE")"
        mpv --no-video --ao=pipewire,sndio,alsa --really-quiet "$@" "$FILE"
        ;;
esac

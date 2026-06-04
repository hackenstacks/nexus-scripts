#!/bin/sh
# nexus-wallpaper-pick.sh — Pick, generate or fetch a wallpaper and apply it
# Sane • Simple • Secure
# Providers: local files, unsplash, picsum, nasa, solid color, gradient

set -e

# ── Config ───────────────────────────────────────────────────
CACHE_DIR="$HOME/.cache/nexus/wallpapers"
WALLPAPER_DIRS="
$HOME/Pictures
$HOME/Pictures/wallpapers
$HOME/wallpapers
/usr/share/lxqt/wallpapers
/usr/share/wallpapers
/usr/share/pixmaps
"

mkdir -p "$CACHE_DIR"

# ── Helpers ──────────────────────────────────────────────────
pick() { fuzzel --dmenu --prompt "$1: "; }
err()  { echo "nexus-wallpaper: $*" >&2; exit 1; }
apply(){ exec "$HOME/scripts/nexus-theme.sh" "$1"; }

# ── Providers ────────────────────────────────────────────────

provider_local() {
    list=$(for d in $WALLPAPER_DIRS; do
        [ -d "$d" ] || continue
        find "$d" -maxdepth 3 \( -iname "*.jpg" -o -iname "*.jpeg" \
            -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null
    done | sort -u)
    [ -z "$list" ] && err "no local images found"
    chosen=$(printf '%s\n' "$list" | pick "Local wallpaper")
    [ -z "$chosen" ] && exit 0
    apply "$chosen"
}

provider_unsplash() {
    query=$(echo "" | pick "Unsplash search (e.g. forest, cyberpunk, space)")
    [ -z "$query" ] && exit 0
    res=$(printf '1920x1080\n2560x1440\n3840x2160\n1280x800' | pick "Resolution")
    [ -z "$res" ] && res="1920x1080"
    w=$(echo "$res" | cut -dx -f1)
    h=$(echo "$res" | cut -dx -f2)
    dest="$CACHE_DIR/unsplash-${query// /_}-${w}x${h}.jpg"
    echo "nexus-wallpaper: fetching from Unsplash..."
    curl -sL "https://source.unsplash.com/${w}x${h}/?${query}" -o "$dest" \
        || err "unsplash fetch failed (check network)"
    apply "$dest"
}

provider_picsum() {
    res=$(printf '1920x1080\n2560x1440\n3840x2160\n1280x800' | pick "Resolution")
    [ -z "$res" ] && res="1920x1080"
    w=$(echo "$res" | cut -dx -f1)
    h=$(echo "$res" | cut -dx -f2)
    seed=$(shuf -i 1-1000 -n 1 2>/dev/null || echo "42")
    dest="$CACHE_DIR/picsum-${seed}-${w}x${h}.jpg"
    echo "nexus-wallpaper: fetching from Picsum (seed $seed)..."
    curl -sL "https://picsum.photos/seed/${seed}/${w}/${h}" -o "$dest" \
        || err "picsum fetch failed (check network)"
    apply "$dest"
}

provider_nasa() {
    echo "nexus-wallpaper: fetching NASA APOD..."
    dest="$CACHE_DIR/nasa-apod-$(date +%Y%m%d).jpg"
    if [ ! -f "$dest" ]; then
        url=$(curl -sL "https://apod.nasa.gov/apod/astropix.html" 2>/dev/null \
            | grep -oE 'image/[0-9]+/[^"]+\.(jpg|jpeg|png)' | head -1)
        [ -z "$url" ] && err "could not parse NASA APOD (check network)"
        curl -sL "https://apod.nasa.gov/apod/${url}" -o "$dest" \
            || err "NASA APOD fetch failed"
    else
        echo "nexus-wallpaper: using cached APOD from today"
    fi
    apply "$dest"
}

provider_solid() {
    color=$(echo "" | pick "Hex color (e.g. 1a1b26, 282a36, 0d1117)")
    [ -z "$color" ] && exit 0
    color=$(echo "$color" | sed 's/^#//')
    res=$(printf '1920x1080\n2560x1440\n3840x2160' | pick "Resolution")
    [ -z "$res" ] && res="1920x1080"
    w=$(echo "$res" | cut -dx -f1)
    h=$(echo "$res" | cut -dx -f2)
    dest="$CACHE_DIR/solid-${color}-${w}x${h}.png"
    command -v convert >/dev/null 2>&1 || err "imagemagick required (apk add imagemagick)"
    convert -size "${w}x${h}" "xc:#${color}" "$dest"
    apply "$dest"
}

provider_gradient() {
    c1=$(echo "" | pick "Color 1 (hex, e.g. 1a1b26)")
    [ -z "$c1" ] && exit 0
    c2=$(echo "" | pick "Color 2 (hex, e.g. 7aa2f7)")
    [ -z "$c2" ] && exit 0
    dir=$(printf 'horizontal\nvertical\ndiagonal' | pick "Direction")
    [ -z "$dir" ] && dir="horizontal"
    res=$(printf '1920x1080\n2560x1440\n3840x2160' | pick "Resolution")
    [ -z "$res" ] && res="1920x1080"
    w=$(echo "$res" | cut -dx -f1)
    h=$(echo "$res" | cut -dx -f2)
    dest="$CACHE_DIR/gradient-${c1}-${c2}-${w}x${h}.png"
    command -v convert >/dev/null 2>&1 || err "imagemagick required (apk add imagemagick)"
    case "$dir" in
        vertical)  convert -size "${w}x${h}" "gradient:#${c1}-#${c2}" "$dest" ;;
        diagonal)  convert -size "${w}x${h}" "gradient:#${c1}-#${c2}" \
                       -rotate -45 -gravity center -extent "${w}x${h}" "$dest" ;;
        *)         convert -size "${w}x${h}" "gradient:#${c1}-#${c2}" -rotate 90 "$dest" ;;
    esac
    apply "$dest"
}

provider_cache() {
    list=$(find "$CACHE_DIR" -maxdepth 1 \( -iname "*.jpg" -o -iname "*.png" \) 2>/dev/null | sort)
    [ -z "$list" ] && err "no cached wallpapers found"
    chosen=$(printf '%s\n' "$list" | pick "Cached wallpaper")
    [ -z "$chosen" ] && exit 0
    apply "$chosen"
}

# ── Main ─────────────────────────────────────────────────────
case "${1:-menu}" in
    local)      provider_local ;;
    unsplash)   provider_unsplash ;;
    picsum)     provider_picsum ;;
    nasa)       provider_nasa ;;
    solid)      provider_solid ;;
    gradient)   provider_gradient ;;
    cache)      provider_cache ;;
    menu|"")
        provider=$(printf 'local\nunsplash\npicsum\nnasa\nsolid color\ngradient\ncache' \
            | pick "Wallpaper provider")
        [ -z "$provider" ] && exit 0
        case "$provider" in
            local)        provider_local ;;
            unsplash)     provider_unsplash ;;
            picsum)       provider_picsum ;;
            nasa)         provider_nasa ;;
            "solid color") provider_solid ;;
            gradient)     provider_gradient ;;
            cache)        provider_cache ;;
        esac
        ;;
    *)
        echo "Usage: $0 {local|unsplash|picsum|nasa|solid|gradient|cache}"
        echo "       $0   — interactive provider menu via fuzzel"
        ;;
esac

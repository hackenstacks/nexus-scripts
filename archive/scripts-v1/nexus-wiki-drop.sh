#!/bin/sh
# nexus-wiki-drop.sh — Drop any .md into the NeXuS wiki
# Usage:
#   nexus-wiki-drop.sh <file.md>               # auto-detect category
#   nexus-wiki-drop.sh <file.md> <section>     # force section
#   nexus-wiki-drop.sh --inbox                 # process all files in ~/wiki-inbox/
#   nexus-wiki-drop.sh --rebuild               # just rebuild the wiki
#
# Add <!-- NEXUS-WIKI section: Security --> to a doc to force its category
# Otherwise filename patterns determine placement (see CATEGORY MAP below)
#
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

WIKI_DIR="$HOME/Documents/nexus-docs"
DOCS_DIR="$WIKI_DIR/docs"
INBOX_DIR="$HOME/wiki-inbox"
MKDOCS_YML="$WIKI_DIR/mkdocs.yml"

# --- CATEGORY MAP ---
# Pattern → subfolder in docs/ → nav section in mkdocs.yml
# Add more as the wiki grows
_detect_section() {
    fname="$1"
    # Check inline meta first
    meta=$(grep -m1 'NEXUS-WIKI section:' "$fname" 2>/dev/null | sed 's/.*section: *//' | tr -d ' -->')
    if [ -n "$meta" ]; then
        echo "$meta"
        return
    fi
    # Filename patterns
    base=$(basename "$fname" .md | tr '[:upper:]' '[:lower:]')
    case "$base" in
        *security*|*psad*|*fwsnort*|*fail2ban*|*apparmor*|*cerberus*|*fortress*) echo "Security" ;;
        *network*|*stack*|*darknet*|*mesh*|*routing*|*i2p*|*tor*|*ygg*|*reticulum*) echo "Network Stack" ;;
        *diva*|*blockchain*|*nexium*|*economy*|*token*|*gleipnir*) echo "Economy" ;;
        *ai*|*chimera*|*oaae*|*intelligence*|*autonomous*) echo "AI" ;;
        *phantom*|*medusa*|*proxy*|*obfus*|*stealth*) echo "Network" ;;
        *fireside*|*chat*|*session*) echo "Fireside Chats" ;;
        *history*|*archive*|*founding*) echo "NeXuS History" ;;
        *report*|*action*) echo "Reports" ;;
        *nexus-defined*|*overview*|*framework*|*what-is*|*boot*) echo "What Is NeXuS" ;;
        *) echo "Development" ;;  # default bucket
    esac
}

_slug() {
    basename "$1" .md | tr '[:upper:]' '[:lower:]' | tr ' _' '-'
}

_add_to_nav() {
    yml="$1"
    section="$2"
    docref="$3"   # e.g. "My Doc: my-doc.md"
    # If section exists in nav, append under it; otherwise add at end before last entry
    # Simple approach: if section header found, insert after it
    if grep -q "^  - ${section}:" "$yml"; then
        # Insert after section header (first item under it)
        sed -i "/^  - ${section}:/a\\    - ${docref}" "$yml"
        echo "  → added under '${section}' in nav"
    else
        # Append new section before Reports (keeps Reports near end)
        sed -i "/^  - Reports:/i\\  - ${section}:\\n    - ${docref}" "$yml"
        echo "  → created new section '${section}' in nav"
    fi
}

_process_file() {
    src="$1"
    forced_section="$2"

    if [ ! -f "$src" ]; then
        echo "ERROR: file not found: $src"
        return 1
    fi

    # Get title from first H1 in file
    title=$(grep -m1 '^# ' "$src" | sed 's/^# //')
    [ -z "$title" ] && title=$(basename "$src" .md)

    section="${forced_section:-$(_detect_section "$src")}"
    slug=$(_slug "$src")
    dest="$DOCS_DIR/${slug}.md"

    # Backup if exists
    if [ -f "$dest" ]; then
        cp "$dest" "${dest}.bak"
        echo "  → backed up existing ${slug}.md"
    fi

    cp "$src" "$dest"
    echo "  → copied to $dest"

    # Only add to nav if not already there
    if ! grep -q "${slug}.md" "$MKDOCS_YML"; then
        _add_to_nav "$MKDOCS_YML" "$section" "${title}: ${slug}.md"
    else
        echo "  → already in nav, skipped"
    fi

    echo "  ✓ ${title} → ${section}"
}

_rebuild() {
    echo "Building wiki..."
    cd "$WIKI_DIR" && mkdocs build --quiet 2>&1 | tail -5
    echo "Done. Run 'mkdocs serve' to preview or 'mkdocs gh-deploy' to publish."
}

# --- MAIN ---
mkdir -p "$INBOX_DIR"

case "$1" in
    --inbox)
        count=0
        for f in "$INBOX_DIR"/*.md; do
            [ -f "$f" ] || continue
            echo "Processing: $(basename "$f")"
            _process_file "$f"
            count=$((count+1))
        done
        [ "$count" -eq 0 ] && echo "Inbox empty: $INBOX_DIR" || _rebuild
        ;;
    --rebuild)
        _rebuild
        ;;
    "")
        echo "Usage: nexus-wiki-drop.sh <file.md> [section]"
        echo "       nexus-wiki-drop.sh --inbox"
        echo "       nexus-wiki-drop.sh --rebuild"
        echo ""
        echo "Drop zones:"
        echo "  ~/wiki-inbox/     — batch drop, run --inbox to publish all"
        echo "  Direct call       — nexus-wiki-drop.sh myfile.md"
        echo ""
        echo "Force section with inline meta:"
        echo "  <!-- NEXUS-WIKI section: Security -->"
        ;;
    *)
        echo "Processing: $(basename "$1")"
        _process_file "$1" "$2"
        _rebuild
        ;;
esac

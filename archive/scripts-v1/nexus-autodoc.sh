#!/bin/sh
# NeXuS AutoDoc — Automatic documentation population
# Watches ~/.nb/nexus-docs/ → syncs to MkDocs → updates nav
# Sane • Simple • Secure
#
# Usage:
#   nexus-autodoc.sh            # run as daemon
#   nexus-autodoc.sh --sync     # one-time sync, no watch
#   nexus-autodoc.sh --status   # show what would be synced
#
# Note frontmatter in nb notes controls nav placement:
#
#   ---
#   title: My Document Title
#   nexus_nav: Security
#   ---
#
# Nav sections: "Home" | "What Is NeXuS" | "Network" | "Security" |
#               "AI" | "Architecture" | "Development" | "Fireside Chats" |
#               "Node" | "NeXuS Family" | "RIN"
#
# If nexus_nav is absent, section is inferred from filename.

NB_DIR="$HOME/.nb/nexus-docs"
DOCS_DIR="$HOME/Documents/nexus-docs/docs"
MKDOCS_YML="$HOME/Documents/nexus-docs/mkdocs.yml"
LOG="/tmp/nexus-autodoc.log"
PID_FILE="/tmp/nexus-autodoc.pid"

# ── colours ─────────────────────────────────────────────────────────────────
G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'; R='\033[0;31m'; N='\033[0m'
ok()   { printf "  ${G}✓${N} %s\n" "$1"; }
warn() { printf "  ${Y}⚠${N}  %s\n" "$1"; }
info() { printf "  ${C}▸${N} %s\n" "$1"; }
err()  { printf "  ${R}✗${N} %s\n" "$1"; }

log() { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"; }

# ── infer nav section from filename ─────────────────────────────────────────
infer_nav() {
    fname="$1"
    case "$fname" in
        fireside-chat-*)    echo "Fireside Chats" ;;
        nexus-defined*)     echo "What Is NeXuS" ;;
        nexus-overview*)    echo "What Is NeXuS" ;;
        what-is-nexus*)     echo "What Is NeXuS" ;;
        oaae-*)             echo "What Is NeXuS" ;;
        nexus-blueprint*)   echo "What Is NeXuS" ;;
        medusa-*)           echo "Network" ;;
        zombie-*)           echo "Network" ;;
        security-*|*-security*|psad-*|fwsnort-*|cerberus-*|3key-*|point*) echo "Security" ;;
        ai-*|dpfoe-*|chimera-*|autonomo*|event-horizon*|merged-*) echo "AI" ;;
        economy-*|nexus-mint-*|nexus-architect*|install-arch*|required-*|nexus-rings*) echo "Architecture" ;;
        cli-*|contrib*)     echo "Development" ;;
        rin*)               echo "RIN" ;;
        education-*)        echo "NeXuS Family" ;;
        node-*)             echo "Node" ;;
        *)                  echo "Home" ;;
    esac
}

# ── extract frontmatter value ────────────────────────────────────────────────
get_front() {
    key="$1"; file="$2"
    awk "/^---/{f++} f==1 && /^${key}:/{gsub(/^${key}:[[:space:]]*/,\"\"); print; exit}" "$file"
}

# ── get clean title from file ────────────────────────────────────────────────
get_title() {
    file="$1"
    # try frontmatter title
    t=$(get_front "title" "$file")
    if [ -n "$t" ]; then echo "$t"; return; fi
    # try first H1
    t=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //')
    if [ -n "$t" ]; then echo "$t"; return; fi
    # fallback to filename
    basename "$file" .md | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}'
}

# ── check if file already exists in mkdocs.yml nav ──────────────────────────
nav_has_file() {
    fname="$1"
    grep -q "${fname}" "$MKDOCS_YML" 2>/dev/null
}

# ── inject file into mkdocs.yml nav ─────────────────────────────────────────
inject_nav() {
    title="$1"; section="$2"; fname="$3"

    # Skip if already in nav
    if nav_has_file "$fname"; then
        return 0
    fi

    python3 - "$MKDOCS_YML" "$section" "$title" "$fname" << 'PYEOF'
import sys, re

yml_path  = sys.argv[1]
section   = sys.argv[2]
title     = sys.argv[3]
fname     = sys.argv[4]
new_entry = f"    - {title}: {fname}"

with open(yml_path, 'r') as f:
    content = f.read()

# Find the section header and append the entry after it
pattern = rf"(  - {re.escape(section)}:\n)"
replacement = rf"\1{new_entry}\n"

if re.search(pattern, content):
    new_content = re.sub(pattern, replacement, content, count=1)
    with open(yml_path, 'w') as f:
        f.write(new_content)
    print(f"injected: {title} → {section}")
else:
    # Section not found — append to end of nav before markdown_extensions
    insert = f"\n  - {section}:\n{new_entry}\n"
    new_content = content.replace('\nmarkdown_extensions:', insert + '\nmarkdown_extensions:')
    with open(yml_path, 'w') as f:
        f.write(new_content)
    print(f"new section created: {section} → {title}")
PYEOF
}

# ── process one file ─────────────────────────────────────────────────────────
process_file() {
    src="$1"
    fname=$(basename "$src")

    # Skip non-markdown, duplicates (-1 suffixed), system files
    case "$fname" in
        *.md) ;;
        *) return ;;
    esac
    case "$fname" in
        *-1.md|CHANGELOG*|CLAUDE*|*.bak*) return ;;
    esac

    dest="$DOCS_DIR/$fname"

    # Copy file
    cp "$src" "$dest"

    # Get title and nav section
    title=$(get_title "$src")
    nav=$(get_front "nexus_nav" "$src")
    [ -z "$nav" ] && nav=$(infer_nav "$fname")

    # Inject into nav
    inject_nav "$title" "$nav" "$fname" 2>/dev/null && \
        ok "$fname → $nav" || \
        info "$fname already in nav"

    log "synced: $fname → $nav ($title)"
}

# ── one-time sync all nb notes ───────────────────────────────────────────────
sync_all() {
    info "Syncing ~/.nb/nexus-docs → MkDocs..."
    count=0
    for f in "$NB_DIR"/*.md; do
        [ -f "$f" ] || continue
        process_file "$f"
        count=$((count + 1))
    done
    ok "Sync complete — $count files processed"
}

# ── status report ─────────────────────────────────────────────────────────────
show_status() {
    info "AutoDoc Status"
    printf "  NB source:  %s\n" "$NB_DIR"
    printf "  MkDocs dir: %s\n" "$DOCS_DIR"
    printf "\n  Files in nb not yet in MkDocs nav:\n"
    found=0
    for f in "$NB_DIR"/*.md; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        case "$fname" in *-1.md|CHANGELOG*|CLAUDE*) continue ;; esac
        if ! nav_has_file "$fname"; then
            printf "    • %s\n" "$fname"
            found=$((found + 1))
        fi
    done
    [ "$found" -eq 0 ] && printf "    (all synced)\n"
}

# ── watch daemon ─────────────────────────────────────────────────────────────
run_daemon() {
    echo $$ > "$PID_FILE"
    info "NeXuS AutoDoc watching $NB_DIR"
    log "AutoDoc daemon started"

    # Initial sync
    sync_all

    # Watch for changes
    inotifywait -m -e close_write,moved_to --format '%f' "$NB_DIR" 2>/dev/null | \
    while read -r fname; do
        src="$NB_DIR/$fname"
        [ -f "$src" ] || continue
        info "Change detected: $fname"
        process_file "$src"
    done
}

# ── main ─────────────────────────────────────────────────────────────────────
case "${1:-}" in
    --sync)   sync_all ;;
    --status) show_status ;;
    --stop)
        if [ -f "$PID_FILE" ]; then
            kill "$(cat "$PID_FILE")" 2>/dev/null && ok "AutoDoc stopped"
            rm -f "$PID_FILE"
        else
            warn "AutoDoc not running"
        fi
        ;;
    *)        run_daemon ;;
esac

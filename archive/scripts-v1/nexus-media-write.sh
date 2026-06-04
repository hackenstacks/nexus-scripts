#!/bin/sh
# nexus-media-write.sh — NeXuS Publishing Desk
# Write → publish to NeXuS wiki, MkDocs site, or IPFS darknet
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY"

DRAFT_DIR="$HOME/notes/drafts"
WIKI_DIR="$HOME/Documents/nexus-docs/docs"
SCRIPTS="$HOME/scripts"
mkdir -p "$DRAFT_DIR"

_header() {
    clear
    printf "\n  ${CYN}${BOLD}📡  NEXUS PUBLISHING DESK${R}\n"
    printf "  ${GRY}───────────────────────────────────────────────${R}\n"
    printf "  ${DIM}Write · Edit · Publish to Wiki · Deploy to Net${R}\n\n"
}

# ── Destination status ─────────────────────────────────────────────────────
_dest_status() {
    # Wiki (MkDocs)
    if [ -d "$WIKI_DIR" ]; then
        printf "  ${GRN}●${R} ${WHT}NeXuS Wiki${R}      ${GRY}%s${R}\n" "$WIKI_DIR"
    else
        printf "  ${RED}●${R} ${WHT}NeXuS Wiki${R}      ${GRY}not found${R}\n"
    fi
    # GitHub Pages
    if git -C "$HOME/Documents/nexus-docs" remote -v 2>/dev/null | grep -q origin; then
        remote=$(git -C "$HOME/Documents/nexus-docs" remote get-url origin 2>/dev/null)
        printf "  ${GRN}●${R} ${WHT}GitHub Pages${R}    ${GRY}%s${R}\n" "$remote"
    else
        printf "  ${GRY}●${R} ${WHT}GitHub Pages${R}    ${GRY}not configured${R}\n"
    fi
    # IPFS
    if command -v ipfs >/dev/null 2>&1; then
        printf "  ${GRN}●${R} ${WHT}IPFS${R}            ${GRY}ready${R}\n"
    else
        printf "  ${GRY}●${R} ${WHT}IPFS${R}            ${GRY}not installed${R}\n"
    fi
}

# ── Draft listing ─────────────────────────────────────────────────────────
_list_drafts() {
    count=$(ls "$DRAFT_DIR"/*.md 2>/dev/null | wc -l)
    printf "  ${BOLD}${WHT}DRAFTS${R}  ${GRY}(${count} files)${R}\n"
    ls "$DRAFT_DIR"/*.md 2>/dev/null | while read f; do
        mod=$(date -r "$f" '+%m/%d' 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -d' ' -f1)
        printf "  ${GRY}·${R} ${WHT}%-30s${R} ${GRY}%s${R}\n" "$(basename "$f" .md)" "$mod"
    done
    [ "$count" -eq 0 ] && printf "  ${GRY}No drafts yet — press [n] to start writing${R}\n"
}

# ── New draft ─────────────────────────────────────────────────────────────
_new_draft() {
    printf "\n  ${CYN}Title${R} > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r title
    stty "$old" 2>/dev/null
    [ -z "$title" ] && return
    slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    file="$DRAFT_DIR/${slug}-$(date +%Y%m%d).md"
    printf "  Category (security/network/ai/nexus/general) > "
    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
    IFS= read -r cat
    stty "$old" 2>/dev/null
    [ -z "$cat" ] && cat="general"
    {
        printf "---\n"
        printf "title: %s\n" "$title"
        printf "date: %s\n" "$(date '+%Y-%m-%d')"
        printf "category: %s\n" "$cat"
        printf "tags: [nexus]\n"
        printf "draft: true\n"
        printf "---\n\n"
        printf "# %s\n\n" "$title"
        printf "> *%s*\n\n" "$(date '+%B %d, %Y')"
        printf "## Overview\n\n"
        printf "\n## Details\n\n"
        printf "\n## References\n\n"
    } > "$file"
    micro "$file"
    _after_edit "$file"
}

# ── Edit existing draft ───────────────────────────────────────────────────
_edit_draft() {
    file=$(ls "$DRAFT_DIR"/*.md 2>/dev/null | \
        fzf --prompt="Draft > " \
            --preview="head -30 {}" \
            --preview-window=right:55% 2>/dev/null)
    [ -z "$file" ] && return
    micro "$file"
    _after_edit "$file"
}

# ── After edit: offer publish options ────────────────────────────────────
_after_edit() {
    file="$1"
    [ -z "$file" ] || [ ! -f "$file" ] && return
    title=$(grep '^title:' "$file" | cut -d: -f2- | sed 's/^ //')
    [ -z "$title" ] && title=$(basename "$file" .md)

    clear
    printf "\n  ${CYN}${BOLD}PUBLISH:${R} ${WHT}%s${R}\n\n" "$title"
    printf "  ${CYN}[w]${R}  Copy to NeXuS Wiki (local MkDocs)\n"
    printf "  ${CYN}[p]${R}  Publish to GitHub Pages (mkdocs gh-deploy)\n"
    printf "  ${CYN}[i]${R}  Pin to IPFS (if available)\n"
    printf "  ${CYN}[b]${R}  Both wiki + GitHub Pages\n"
    printf "  ${CYN}[s]${R}  Save draft only\n"
    printf "  ${CYN}[q]${R}  Cancel\n\n"

    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old" 2>/dev/null

    case "$key" in
        w|W) _pub_wiki "$file" ;;
        p|P) _pub_ghpages "$file" ;;
        i|I) _pub_ipfs "$file" ;;
        b|B) _pub_wiki "$file" && _pub_ghpages "$file" ;;
        s|S) printf "  ${GRN}Draft saved:${R} %s\n" "$file" ;;
        q|Q) return ;;
    esac
    printf "\n  Press any key to continue..."
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null >/dev/null
    stty "$old" 2>/dev/null
}

# ── Publish to local wiki ─────────────────────────────────────────────────
_pub_wiki() {
    file="$1"
    [ ! -d "$WIKI_DIR" ] && printf "  ${RED}Wiki dir not found: %s${R}\n" "$WIKI_DIR" && return 1
    cat=$(grep '^category:' "$file" | cut -d: -f2- | sed 's/^ //')
    [ -z "$cat" ] && cat="notes"
    dest="$WIKI_DIR/$cat"
    mkdir -p "$dest"
    cp "$file" "$dest/"
    printf "  ${GRN}✓${R} Copied to wiki: ${GRY}%s/%s${R}\n" "$cat" "$(basename "$file")"
    # Remove draft: true frontmatter flag
    sed -i 's/^draft: true/draft: false/' "$dest/$(basename "$file")" 2>/dev/null
    # Auto-wire into mkdocs nav if nexus-wiki-drop.sh exists
    if [ -x "$SCRIPTS/nexus-wiki-drop.sh" ]; then
        "$SCRIPTS/nexus-wiki-drop.sh" "$dest/$(basename "$file")" 2>/dev/null && \
            printf "  ${GRN}✓${R} Auto-indexed in mkdocs.yml\n"
    fi
}

# ── Deploy to GitHub Pages ────────────────────────────────────────────────
_pub_ghpages() {
    [ ! -d "$HOME/Documents/nexus-docs" ] && printf "  ${RED}nexus-docs not found${R}\n" && return 1
    printf "  ${YLW}Deploying to GitHub Pages...${R}\n"
    ( cd "$HOME/Documents/nexus-docs" && mkdocs gh-deploy 2>&1 | tail -5 )
    printf "  ${GRN}✓${R} Deployed → https://hackenstacks.github.io/nexus/\n"
}

# ── Pin to IPFS ───────────────────────────────────────────────────────────
_pub_ipfs() {
    file="$1"
    if ! command -v ipfs >/dev/null 2>&1; then
        printf "  ${GRY}IPFS not installed — skipping${R}\n"
        return 1
    fi
    cid=$(ipfs add -q "$file" 2>/dev/null)
    [ -z "$cid" ] && printf "  ${RED}IPFS add failed${R}\n" && return 1
    printf "  ${GRN}✓${R} IPFS CID: ${CYN}%s${R}\n" "$cid"
    printf "  ${GRY}ipfs cat %s${R}\n" "$cid"
    # Save CID to local record
    echo "$(date '+%Y-%m-%d %H:%M')  $cid  $(basename "$file")" >> "$HOME/.nexus/ipfs_published.log"
}

# ── View published IPFS log ───────────────────────────────────────────────
_view_ipfs_log() {
    [ ! -f "$HOME/.nexus/ipfs_published.log" ] && printf "  ${GRY}No IPFS publishes yet${R}\n" && sleep 2 && return
    printf "\n  ${CYN}${BOLD}IPFS Published${R}\n"
    printf "  ${GRY}──────────────────────────────────${R}\n"
    cat "$HOME/.nexus/ipfs_published.log" | while IFS= read -r line; do
        printf "  ${GRY}%s${R}\n" "$line"
    done
    printf "\n  Press any key..."
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null >/dev/null
    stty "$old" 2>/dev/null
}

# ── Main loop ─────────────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    _header
    _dest_status
    printf "\n"
    _list_drafts
    printf "\n"
    printf "  ${CYN}${BOLD}[n]${R}  New post\n"
    printf "  ${CYN}${BOLD}[e]${R}  Edit / publish draft\n"
    printf "  ${CYN}${BOLD}[I]${R}  View IPFS publish log\n"
    printf "  ${CYN}${BOLD}[q]${R}  Quit\n\n"
    printf "  ${GRY}────────────────────────────────────────────────${R}\n"
    printf "  ${GRY}Destinations: NeXuS Wiki · GitHub Pages · IPFS${R}\n\n"

    stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old_stty" 2>/dev/null

    case "$key" in
        n|N) _new_draft ;;
        e|E) _edit_draft ;;
        I)   _view_ipfs_log ;;
        q|Q) exit 0 ;;
    esac
done

#!/bin/bash
# nexus-notes.sh — Simple CLI notes manager for NeXuS tmux popup
# Uses fzf to select, glow to preview, micro to edit
# Notes stored as .md files in ~/notes/nexus/

NOTES_DIR="$HOME/notes/nexus"
mkdir -p "$NOTES_DIR"

# ── Helpers ───────────────────────────────────────────────────────────────────
_preview_cmd() {
    if command -v glow &>/dev/null; then
        echo "glow --style dark {}"
    elif command -v bat &>/dev/null; then
        echo "bat --color=always --style=plain {}"
    else
        echo "cat {}"
    fi
}

_editor() {
    if command -v micro &>/dev/null; then echo "micro"
    elif [[ -n "$VISUAL" ]]; then echo "$VISUAL"
    elif command -v nano &>/dev/null; then echo "nano"
    else echo "vim"
    fi
}

_note_title() {
    # Extract first H1 heading or filename
    local file="$1"
    local heading
    heading=$(grep -m1 "^# " "$file" 2>/dev/null | sed 's/^# //')
    if [[ -n "$heading" ]]; then
        echo "$heading"
    else
        basename "$file" .md
    fi
}

# ── New note ──────────────────────────────────────────────────────────────────
new_note() {
    local title
    echo ""
    echo -n "  Note title: "
    read -r title
    [[ -z "$title" ]] && return

    local slug
    slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    local datestamp
    datestamp=$(date +%Y-%m-%d)
    local file="$NOTES_DIR/${datestamp}-${slug}.md"

    cat > "$file" << EOF
# $title
*Created: $(date '+%Y-%m-%d %H:%M')*

---

EOF

    micro +6 "$file"
}

# ── Quick note (one-liner append) ─────────────────────────────────────────────
quick_note() {
    local file="$NOTES_DIR/quick-notes.md"
    if [[ ! -f "$file" ]]; then
        echo -e "# Quick Notes\n" > "$file"
    fi
    echo -n "Quick note: "
    read -r content
    [[ -z "$content" ]] && echo "Cancelled." && return
    echo "- $(date '+%Y-%m-%d %H:%M') — $content" >> "$file"
    echo "Saved."
    sleep 0.8
}

# ── List + select with fzf ────────────────────────────────────────────────────
list_notes() {
    local notes=()
    local labels=()

    # Build list of notes
    while IFS= read -r -d '' file; do
        notes+=("$file")
        labels+=("$(_note_title "$file")  $(date -r "$file" '+%Y-%m-%d' 2>/dev/null)")
    done < <(find "$NOTES_DIR" -name "*.md" -print0 2>/dev/null | sort -z -r)

    if [[ ${#notes[@]} -eq 0 ]]; then
        echo "No notes yet. Create one with [n]."
        return
    fi

    # fzf selection with preview
    local selected_label
    selected_label=$(printf '%s\n' "${labels[@]}" | \
        fzf --prompt="Notes > " \
            --height=90% \
            --layout=reverse \
            --border=rounded \
            --preview="$(_preview_cmd)" \
            --preview-window=right:60%:wrap \
            --bind="ctrl-d:execute(rm {} && echo Deleted)+reload(find $NOTES_DIR -name '*.md' | sort -r)" \
            --header="Enter=open  Ctrl+D=delete  Esc=back" \
            --color=header:italic)

    [[ -z "$selected_label" ]] && return

    # Find matching file
    local idx=0
    for label in "${labels[@]}"; do
        if [[ "$label" == "$selected_label" ]]; then
            $(_editor) "${notes[$idx]}"
            break
        fi
        ((idx++))
    done
}

# ── Better fzf approach using filenames + titles ──────────────────────────────
browse_notes() {
    [[ ! -d "$NOTES_DIR" ]] && mkdir -p "$NOTES_DIR"

    local selected
    selected=$(find "$NOTES_DIR" -name "*.md" 2>/dev/null | sort -r | \
        fzf --prompt="  Notes > " \
            --height=100% \
            --layout=reverse \
            --border=rounded \
            --preview="glow --style=dark {} 2>/dev/null || bat --color=always --style=plain {} 2>/dev/null || cat {}" \
            --preview-window="right:55%:wrap" \
            --header="[ NeXuS Notes ]  Enter=edit  Ctrl+N=new  Ctrl+D=delete  Esc=quit" \
            --bind="ctrl-n:execute(bash $HOME/scripts/nexus-notes.sh new < /dev/tty > /dev/tty 2>&1)+reload(find $NOTES_DIR -name '*.md' | sort -r)" \
            --delimiter=/ \
            --with-nth=-1 \
            --color="header:italic,border:cyan")

    [[ -n "$selected" ]] && $(_editor) "$selected"
}

# ── Main menu ─────────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        clear
        echo "╔══════════════════════════════╗"
        echo "║       NeXuS  Notes           ║"
        echo "╠══════════════════════════════╣"
        echo "║  [b] Browse / Open notes     ║"
        echo "║  [n] New note                ║"
        echo "║  [q] Quick note (one-liner)  ║"
        echo "║  [x] Exit                    ║"
        echo "╚══════════════════════════════╝"
        echo ""
        echo -n "Choice: "
        read -r -n1 choice
        echo ""

        case "$choice" in
            b|B) browse_notes ;;
            n|N) new_note ;;
            q|Q) quick_note ;;
            x|X|q|"") break ;;
        esac
    done
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "$1" in
    new)   new_note ;;
    quick) quick_note ;;
    browse) browse_notes ;;
    *)     main_menu ;;
esac

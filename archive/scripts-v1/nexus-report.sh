#!/bin/bash
# 🔥 NeXuS Report System
# Creates and manages project-specific action reports with central symlinks.
# Sane • Simple • Secure
#
# Usage:
#   nexus-report.sh <project-path> <title> <body>
#   nexus-report.sh --init <project-path>          # Initialize docs/ for a project
#   nexus-report.sh --list                          # Show all project reports
#   nexus-report.sh --hub                           # Open central reports hub
#
# Called by Claude after completing each task (not at end of session).

set -euo pipefail

REPORTS_HUB="$HOME/claude/reports"
MASTER_REPORT="$HOME/claude/action_report.md"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
step() { echo -e "\n${CYAN}▸${NC} ${WHITE}$1${NC}"; }

# ============================================================
# Initialize docs/ structure for a project
# ============================================================
init_project_docs() {
    local project_path="$1"

    # Resolve to absolute path
    project_path=$(cd "$project_path" 2>/dev/null && pwd)

    if [[ ! -d "$project_path" ]]; then
        echo "Error: $project_path is not a directory"
        return 1
    fi

    local project_name
    project_name=$(basename "$project_path")
    local docs_dir="$project_path/docs"

    mkdir -p "$docs_dir"

    # Create action_report.md if it doesn't exist
    if [[ ! -f "$docs_dir/action_report.md" ]]; then
        cat > "$docs_dir/action_report.md" << EOF
# ${project_name} - Action Report

**Project:** ${project_path}
**Created:** $(date '+%Y-%m-%d')

---

EOF
        ok "Created $docs_dir/action_report.md"
    else
        ok "Report already exists: $docs_dir/action_report.md"
    fi

    # Create/update symlink in central hub
    ensure_symlink "$project_path"

    ok "Project docs initialized: $docs_dir/"
}

# ============================================================
# Ensure symlink exists in central hub
# ============================================================
ensure_symlink() {
    local project_path="$1"
    local project_name
    project_name=$(basename "$project_path")
    local report_file="$project_path/docs/action_report.md"
    local link_path="$REPORTS_HUB/${project_name}.md"

    mkdir -p "$REPORTS_HUB"

    if [[ -f "$report_file" ]]; then
        # Remove old symlink if it exists
        rm -f "$link_path"
        ln -s "$report_file" "$link_path"
        ok "Symlink: $link_path -> $report_file"
    fi
}

# ============================================================
# Append a task report to a project
# ============================================================
append_report() {
    local project_path="$1"
    local title="$2"
    local body="$3"

    # Resolve to absolute path
    project_path=$(cd "$project_path" 2>/dev/null && pwd)

    local project_name
    project_name=$(basename "$project_path")
    local docs_dir="$project_path/docs"
    local report_file="$docs_dir/action_report.md"

    # Auto-init if needed
    if [[ ! -f "$report_file" ]]; then
        init_project_docs "$project_path"
    fi

    # Append the task entry
    cat >> "$report_file" << EOF

## ${title} ($(date '+%Y-%m-%d %H:%M'))

${body}

---

EOF

    ok "Report appended to: $report_file"

    # Also add a one-line summary + link to master report
    local summary_line="- **$(date '+%Y-%m-%d %H:%M')** [${project_name}] ${title} → \`${report_file}\`"

    # Check if master report has a project links section
    if ! grep -q "## Project Report Links" "$MASTER_REPORT" 2>/dev/null; then
        cat >> "$MASTER_REPORT" << 'EOF'

---

## Project Report Links

_Auto-generated links to project-specific reports. See ~/claude/reports/ for symlinks._

EOF
    fi

    # Append summary to master
    echo "$summary_line" >> "$MASTER_REPORT"
    ok "Summary added to master report"

    # Ensure symlink
    ensure_symlink "$project_path"
}

# ============================================================
# List all project reports
# ============================================================
list_reports() {
    step "Project Reports"
    echo ""

    if [[ ! -d "$REPORTS_HUB" ]] || [[ -z "$(ls -A "$REPORTS_HUB" 2>/dev/null)" ]]; then
        warn "No project reports linked yet"
        return
    fi

    printf "  ${WHITE}%-25s %-12s %s${NC}\n" "PROJECT" "ENTRIES" "PATH"
    echo "  ───────────────────────────────────────────────────────────────"

    for link in "$REPORTS_HUB"/*.md; do
        [[ -L "$link" ]] || continue
        local name
        name=$(basename "$link" .md)
        local target
        target=$(readlink -f "$link")

        if [[ -f "$target" ]]; then
            local entries
            entries=$(grep -c '^## ' "$target" 2>/dev/null || echo "0")
            printf "  ${GREEN}%-25s${NC} %-12s %s\n" "$name" "$entries" "$target"
        else
            printf "  ${YELLOW}%-25s${NC} %-12s %s\n" "$name" "BROKEN" "$target"
        fi
    done

    echo ""
    ok "Hub: $REPORTS_HUB/"
    ok "Master: $MASTER_REPORT"
}

# ============================================================
# Scan for existing projects and create missing symlinks
# ============================================================
scan_projects() {
    step "Scanning for projects with docs/action_report.md"

    local found=0
    for dir in "$HOME/Projects"/*/ "$HOME/git"/*/ "$HOME/scripts" "$HOME/claude"; do
        [[ -d "$dir" ]] || continue
        if [[ -f "$dir/docs/action_report.md" ]]; then
            ensure_symlink "$dir"
            ((found++))
        fi
    done

    ok "Found $found projects with reports"
}

# ============================================================
# Main
# ============================================================
case "${1:-}" in
    --init)
        init_project_docs "${2:?Usage: nexus-report.sh --init <project-path>}"
        ;;
    --list)
        list_reports
        ;;
    --scan)
        scan_projects
        ;;
    --hub)
        echo "$REPORTS_HUB"
        ls -la "$REPORTS_HUB/" 2>/dev/null
        ;;
    --help|-h|"")
        echo "NeXuS Report System"
        echo ""
        echo "Usage:"
        echo "  nexus-report.sh <project-path> <title> <body>"
        echo "  nexus-report.sh --init <project-path>"
        echo "  nexus-report.sh --list"
        echo "  nexus-report.sh --scan"
        echo "  nexus-report.sh --hub"
        echo ""
        echo "Examples:"
        echo "  nexus-report.sh ~/git/medusa-proxy 'Added ExcludeNodes support' 'Modified tor.py and tor.cfg...'"
        echo "  nexus-report.sh --init ~/Projects/nexus-node/divachain"
        ;;
    *)
        # Positional: <project-path> <title> <body>
        project="${1:?Usage: nexus-report.sh <project-path> <title> <body>}"
        title="${2:?Missing title}"
        body="${3:?Missing body}"
        append_report "$project" "$title" "$body"
        ;;
esac

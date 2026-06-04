#!/bin/sh
# labwc-apps-menu.sh — Dynamic applications menu for labwc right-click
# Reads .desktop files and outputs labwc-compatible XML grouped by category.

SEARCH_DIRS="/usr/share/applications $HOME/.local/share/applications"
TMP=$(mktemp /tmp/labwc-menu-XXXXXX)

# Parse .desktop files → collect "category|name|exec" lines
for dir in $SEARCH_DIRS; do
    [ -d "$dir" ] || continue
    for f in "$dir"/*.desktop; do
        [ -f "$f" ] || continue

        name="" exec_cmd="" nodisplay="" categories="" terminal=""

        while IFS='=' read -r key val; do
            # Only read [Desktop Entry] section; stop at next section
            case "$key" in
                \[*)  [ "$key" != "[Desktop Entry]" ] && [ -n "$name$exec_cmd" ] && break ;;
                Name)       [ -z "$name" ]     && name="$val" ;;
                Exec)       [ -z "$exec_cmd" ] && exec_cmd="$val" ;;
                NoDisplay)  nodisplay="$val" ;;
                Categories) [ -z "$categories" ] && categories="$val" ;;
                Terminal)   terminal="$val" ;;
            esac
        done < "$f"

        # Skip hidden or incomplete entries
        [ "$nodisplay" = "true" ] && continue
        [ -z "$name" ] || [ -z "$exec_cmd" ] && continue

        # Strip field codes (%U, %F, %i, etc.) and extra spaces
        exec_cmd=$(printf '%s' "$exec_cmd" | sed 's/ *%[a-zA-Z]//g; s/^ *//; s/ *$//')

        # Wrap terminal apps in foot
        [ "$terminal" = "true" ] && exec_cmd="foot -e $exec_cmd"

        # Map first category to friendly group name
        cat=$(printf '%s' "$categories" | cut -d';' -f1)
        case "$cat" in
            AudioVideo|Audio|Video) cat="Sound & Video" ;;
            Development)            cat="Development"   ;;
            Education)              cat="Education"     ;;
            Game)                   cat="Games"         ;;
            Graphics)               cat="Graphics"      ;;
            Network)                cat="Internet"      ;;
            Office)                 cat="Office"        ;;
            Settings)               cat="Settings"      ;;
            System)                 cat="System"        ;;
            Utility|Utilities)      cat="Utilities"     ;;
            *)                      cat="Other"         ;;
        esac

        # XML-escape name and exec
        name_x=$(printf '%s' "$name"     | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
        exec_x=$(printf '%s' "$exec_cmd" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

        printf '%s|%s|%s\n' "$cat" "$name_x" "$exec_x"
    done
done | sort -t'|' -k1,1 -k2,2 > "$TMP"

# Output labwc XML
printf '<?xml version="1.0" encoding="UTF-8"?>\n<openbox_menu>\n<menu id="apps-pipe" label="Applications">\n'

awk -F'|' '
{
    cat=$1; name=$2; exec_cmd=$3
    if (cat != last_cat) {
        if (last_cat != "") printf "  </menu>\n"
        # sanitize category name for id attribute
        id_cat = tolower(cat)
        gsub(/[^a-z0-9]/, "-", id_cat)
        printf "  <menu id=\"cat-%s\" label=\"%s\">\n", id_cat, cat
        last_cat = cat
    }
    printf "    <item label=\"%s\"><action name=\"Execute\" command=\"%s\"/></item>\n", name, exec_cmd
}
END {
    if (last_cat != "") printf "  </menu>\n"
}
' "$TMP"

printf '</menu>\n</openbox_menu>\n'
rm -f "$TMP"

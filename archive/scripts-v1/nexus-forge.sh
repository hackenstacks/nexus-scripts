#!/bin/sh
# nexus-forge.sh — NeXuS Digital Forge & Marketplace
# Create · package · price · list digital goods on darknet
# Products: docs, code, AI characters, art, data packs, tools
# Payment: XMR (Monero) subaddresses per listing
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful

R='\033[0m'; BOLD='\033[1m'; DIM='\033[2m'
CYN='\033[38;5;51m'; GRN='\033[38;5;82m'; YLW='\033[38;5;226m'
GRY='\033[38;5;240m'; WHT='\033[38;5;255m'; RED='\033[38;5;196m'
MAG='\033[38;5;177m'; ORG='\033[38;5;214m'
[ -f "$HOME/.nexus/home_colors.sh" ] && . "$HOME/.nexus/home_colors.sh" && \
    CYN="$C_PRIMARY" GRN="$C_SECONDARY" MAG="$C_TERTIARY"

FORGE_DIR="$HOME/.nexus/forge"
LISTINGS_DB="$FORGE_DIR/listings.jsonl"
PRODUCTS_DIR="$FORGE_DIR/products"
STORE_DIR="$FORGE_DIR/store"          # public HTML store
SCRIPTS="$HOME/scripts"
mkdir -p "$FORGE_DIR" "$PRODUCTS_DIR" "$STORE_DIR"
touch "$LISTINGS_DB" 2>/dev/null

# Categories with icons
CATS="document:📄  code:💻  character:🎭  art:🎨  data:📊  tool:🔧  audio:🎵  other:📦"

_header() {
    clear
    printf "\n  ${ORG}${BOLD}⚒  NEXUS FORGE${R}\n"
    printf "  ${GRY}────────────────────────────────────────────────${R}\n"
    printf "  ${DIM}Create · Package · Sell · Deliver via Darknet${R}\n\n"
}

_count_listings() {
    [ -f "$LISTINGS_DB" ] && wc -l < "$LISTINGS_DB" || echo 0
}

_xmr_available() {
    command -v monero-wallet-cli >/dev/null 2>&1 || command -v monero-wallet-rpc >/dev/null 2>&1
}

_forge_status() {
    printf "  ${GRY}Listings:${R} ${WHT}%s${R}  " "$(_count_listings)"
    printf "  ${GRY}Products:${R} ${WHT}%s${R}  " "$(ls "$PRODUCTS_DIR" 2>/dev/null | wc -l | tr -d ' ')"
    if _xmr_available; then
        printf "  ${GRN}● XMR${R}"
    else
        printf "  ${GRY}● XMR (install monero-wallet-cli for payments)${R}"
    fi
    printf "\n\n"
}

# ── List all listings ─────────────────────────────────────────────────────
_list_listings() {
    printf "  ${BOLD}${WHT}LISTINGS${R}\n"
    [ ! -s "$LISTINGS_DB" ] && printf "  ${GRY}No listings yet — press [n] to create your first product${R}\n\n" && return
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        id=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id','?'))" 2>/dev/null)
        title=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('title','?'))" 2>/dev/null)
        price=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('price_xmr','0'))" 2>/dev/null)
        cat=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('category','other'))" 2>/dev/null)
        status=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','draft'))" 2>/dev/null)
        case "$status" in
            live)  sc="${GRN}" ;;
            draft) sc="${GRY}" ;;
            sold)  sc="${YLW}" ;;
            *)     sc="${WHT}" ;;
        esac
        printf "  ${sc}%-8s${R}  ${WHT}%-28s${R}  ${YLW}%s XMR${R}  ${GRY}%s${R}\n" \
            "${id}" "${title}" "${price}" "${cat}"
    done < "$LISTINGS_DB"
    printf "\n"
}

# ── Create new product listing ────────────────────────────────────────────
_new_listing() {
    _header
    printf "  ${ORG}${BOLD}NEW LISTING${R}\n\n"

    old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null

    printf "  Title          > "; IFS= read -r title
    [ -z "$title" ] && stty "$old" 2>/dev/null && return

    printf "  Description    > "; IFS= read -r desc

    # Category picker
    printf "\n  Categories:\n"
    i=1
    echo "$CATS" | tr ' ' '\n' | while IFS=: read -r ckey cicon; do
        printf "  ${CYN}[%d]${R} %s %s\n" "$i" "$cicon" "$ckey"
        i=$((i+1))
    done
    printf "  Choice [1-8]   > "; IFS= read -r cnum
    cat=$(echo "$CATS" | tr ' ' '\n' | sed -n "${cnum}p" | cut -d: -f1)
    [ -z "$cat" ] && cat="other"

    printf "  Price (XMR)    > "; IFS= read -r price_xmr
    [ -z "$price_xmr" ] && price_xmr="0.01"

    printf "  Nexium price   > "; IFS= read -r price_nxm
    [ -z "$price_nxm" ] && price_nxm="100"

    printf "  Tags (space sep)> "; IFS= read -r tags

    printf "  Product files dir (blank=create new) > "; IFS= read -r prod_src

    stty "$old" 2>/dev/null

    # Generate ID
    id="NXF-$(date +%Y%m%d)-$(head -c4 /dev/urandom | xxd -p 2>/dev/null || date +%N | head -c4)"

    # Set up product dir
    prod_dir="$PRODUCTS_DIR/$id"
    mkdir -p "$prod_dir"

    if [ -n "$prod_src" ] && [ -d "$prod_src" ]; then
        cp -r "$prod_src/." "$prod_dir/"
        printf "\n  ${GRN}✓${R} Copied files from %s\n" "$prod_src"
    else
        printf "\n  ${GRY}Creating product scaffold...${R}\n"
        _scaffold_product "$prod_dir" "$title" "$desc" "$cat"
    fi

    # Build JSON listing
    tags_json=$(echo "$tags" | tr ' ' '\n' | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null || echo '[]')
    listing=$(python3 -c "
import json, time
print(json.dumps({
    'id': '$id',
    'title': '$title',
    'description': '$desc',
    'category': '$cat',
    'price_xmr': '$price_xmr',
    'price_nexium': '$price_nxm',
    'tags': $tags_json,
    'product_dir': '$prod_dir',
    'status': 'draft',
    'created': time.strftime('%Y-%m-%d %H:%M'),
    'xmr_address': '',
    'onion': '',
    'i2p': ''
}))" 2>/dev/null)

    echo "$listing" >> "$LISTINGS_DB"
    printf "  ${GRN}✓${R} Listing created: ${CYN}%s${R}\n" "$id"
    printf "\n  ${YLW}Next:${R} press [p] to publish, [e] to edit product files\n"
    printf "\n  Press any key..."
    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    dd bs=1 count=1 2>/dev/null >/dev/null; stty "$old" 2>/dev/null
}

# ── Product file scaffold ─────────────────────────────────────────────────
_scaffold_product() {
    dir="$1" title="$2" desc="$3" cat="$4"
    case "$cat" in
        document|code)
            cat > "$dir/README.md" <<MD
# $title

$desc

## Contents

<!-- Add your content here -->

## License

NeXuS Open License — share freely, attribute the source.
MD
            ;;
        character)
            python3 -c "
import json
print(json.dumps({
    'name': '$title',
    'description': '$desc',
    'category': 'forge',
    'traits': [],
    'backstory': '',
    'abilities': []
}, indent=2))" > "$dir/character.json"
            ;;
        *)
            printf "# %s\n\n%s\n" "$title" "$desc" > "$dir/README.md"
            ;;
    esac
    printf "  ${GRN}✓${R} Scaffold created — edit files at: %s\n" "$dir"
}

# ── Publish listing to store + darknet ───────────────────────────────────
_publish_listing() {
    id=$(grep -v '^$' "$LISTINGS_DB" | \
        python3 -c "
import sys, json
listings = [json.loads(l) for l in sys.stdin if l.strip()]
for l in listings:
    print('{id}  {status:8}  {title}  {price_xmr} XMR'.format(**l))
" 2>/dev/null | fzf --prompt="Publish > " 2>/dev/null | awk '{print $1}')
    [ -z "$id" ] && return

    # Get listing data
    line=$(grep "\"id\": \"$id\"" "$LISTINGS_DB")
    title=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['title'])" 2>/dev/null)
    desc=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description',''))" 2>/dev/null)
    price=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('price_xmr','?'))" 2>/dev/null)
    nxm=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('price_nexium','?'))" 2>/dev/null)
    prod_dir=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('product_dir',''))" 2>/dev/null)

    # Build listing HTML page
    listing_dir="$STORE_DIR/$id"
    mkdir -p "$listing_dir"
    _build_listing_page "$listing_dir" "$id" "$title" "$desc" "$price" "$nxm" "$prod_dir"

    # Rebuild store index
    _build_store_index

    printf "\n  ${GRN}✓${R} Store page built: %s\n" "$listing_dir/index.html"
    printf "\n  ${YLW}Publish where?${R}\n"
    printf "  ${CYN}[t]${R} Tor (.onion)   ${CYN}[i]${R} I2P   ${CYN}[b]${R} Both   ${CYN}[l]${R} Local only\n"

    old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
    net=$(dd bs=1 count=1 2>/dev/null | tr -d '\0'); stty "$old" 2>/dev/null

    case "$net" in
        t|T|b|B) "$SCRIPTS/nexus-darknet-publish.sh" 2>/dev/null &
            printf "\n  ${GRY}→ Opening darknet publish manager to register site${R}\n" ;;
    esac

    # Mark as live
    tmp=$(mktemp)
    while IFS= read -r l; do
        if echo "$l" | grep -q "\"id\": \"$id\""; then
            echo "$l" | python3 -c "import sys,json; d=json.load(sys.stdin); d['status']='live'; import json; print(json.dumps(d))" 2>/dev/null
        else
            echo "$l"
        fi
    done < "$LISTINGS_DB" > "$tmp"
    mv "$tmp" "$LISTINGS_DB"

    printf "\n  ${GRN}${BOLD}%s is live.${R}\n\n" "$title"
    printf "  Press any key..."; old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null; dd bs=1 count=1 2>/dev/null >/dev/null; stty "$old" 2>/dev/null
}

# ── Build HTML listing page ────────────────────────────────────────────────
_build_listing_page() {
    dir="$1" id="$2" title="$3" desc="$4" price_xmr="$5" price_nxm="$6" prod_dir="$7"
    # List product files
    files_html=""
    if [ -d "$prod_dir" ]; then
        files_html="<ul>"
        for f in "$prod_dir"/*; do
            [ -f "$f" ] && files_html="${files_html}<li>$(basename "$f")</li>"
        done
        files_html="${files_html}</ul>"
    fi
    cat > "$dir/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>NeXuS Forge :: ${title}</title>
<style>
  body{background:#0a0a0a;color:#e0e0e0;font-family:monospace;max-width:700px;margin:50px auto;padding:0 20px}
  h1{color:#ff9800;border-bottom:1px solid #1a1a1a;padding-bottom:10px}
  h2{color:#00e5ff;font-size:1em;margin-top:24px}
  .price{font-size:1.4em;color:#82ff6a;font-weight:bold;margin:16px 0}
  .price span{color:#b39ddb;margin-left:12px;font-size:.8em}
  .id{color:#555;font-size:.8em;margin-bottom:16px}
  .files{background:#111;padding:12px;border-left:3px solid #ff9800}
  .files ul{margin:4px 0;padding-left:20px}
  .buy{background:#ff9800;color:#000;padding:10px 20px;border:none;font-family:monospace;
       font-size:1em;cursor:pointer;margin-top:16px;display:inline-block}
  .xmr{background:#111;padding:12px;border-left:3px solid #82ff6a;margin-top:12px;
        word-break:break-all;font-size:.85em}
  hr{border:none;border-top:1px solid #1a1a1a;margin:20px 0}
  .dim{color:#555;font-size:.8em}
</style>
</head>
<body>
<p class="dim">◈ NeXuS Forge</p>
<h1>${title}</h1>
<p class="id">Listing ID: ${id}</p>
<p>${desc}</p>
<div class="price">${price_xmr} XMR <span>${price_nxm} Nexium</span></div>

<h2>CONTENTS</h2>
<div class="files">${files_html}</div>

<h2>HOW TO BUY</h2>
<p>Send exact XMR to the address below. Include your contact method (I2P/Tor address or public key) in the payment ID or message field. Delivery within 24 hours via the same network.</p>
<div class="xmr">
  <strong>XMR Address:</strong><br>
  <!-- XMR subaddress goes here — generated per listing -->
  <em>Address generated after purchase request. Contact via I2P or Tor.</em>
</div>

<hr>
<p class="dim">Powered by NeXuS Forge · Payments via Monero · Delivery via Tor/I2P</p>
<p class="dim">NeXuS: Sane · Simple · Secure · Stealthy · Beautiful</p>
</body>
</html>
HTML
}

# ── Build store index page ────────────────────────────────────────────────
_build_store_index() {
    cards=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        id=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
        title=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('title',''))" 2>/dev/null)
        desc=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description','')[:80])" 2>/dev/null)
        price=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('price_xmr','?'))" 2>/dev/null)
        cat=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('category',''))" 2>/dev/null)
        status=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','draft'))" 2>/dev/null)
        [ "$status" = "live" ] || continue
        cards="${cards}<div class='card'><div class='cat'>${cat}</div><a href='./${id}/'><h3>${title}</h3></a><p>${desc}...</p><div class='price'>${price} XMR</div></div>"
    done < "$LISTINGS_DB"

    cat > "$STORE_DIR/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>NeXuS Forge — Digital Marketplace</title>
<style>
  body{background:#0a0a0a;color:#e0e0e0;font-family:monospace;max-width:900px;margin:50px auto;padding:0 20px}
  h1{color:#ff9800}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:16px;margin-top:24px}
  .card{background:#111;padding:16px;border-left:3px solid #ff9800}
  .card h3{color:#00e5ff;margin:4px 0}
  .card a{text-decoration:none}
  .card p{color:#888;font-size:.85em;margin:6px 0}
  .price{color:#82ff6a;font-weight:bold;margin-top:8px}
  .cat{color:#b39ddb;font-size:.75em;margin-bottom:4px}
  .dim{color:#555;font-size:.8em}
</style>
</head>
<body>
<h1>◈ NeXuS Forge</h1>
<p class="dim">Digital goods marketplace · Payments via Monero · Delivery via Tor/I2P</p>
<div class="grid">
${cards}
</div>
<hr style="border-color:#1a1a1a;margin-top:32px">
<p class="dim">NeXuS: Sane · Simple · Secure · Stealthy · Beautiful</p>
</body>
</html>
HTML
    printf "  ${GRN}✓${R} Store index rebuilt (%s live listings)\n" \
        "$(grep '"status": "live"' "$LISTINGS_DB" 2>/dev/null | wc -l | tr -d ' ')"
}

# ── Edit product files ─────────────────────────────────────────────────────
_edit_product() {
    id=$(grep -v '^$' "$LISTINGS_DB" | \
        python3 -c "
import sys, json
for l in sys.stdin:
    if l.strip():
        d = json.loads(l)
        print('{id}  {title}'.format(**d))
" 2>/dev/null | fzf --prompt="Product > " 2>/dev/null | awk '{print $1}')
    [ -z "$id" ] && return
    prod_dir=$(grep "\"id\": \"$id\"" "$LISTINGS_DB" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('product_dir',''))" 2>/dev/null)
    [ -d "$prod_dir" ] && tmux new-window -n "EDIT-$id" "cd '$prod_dir' && micro ." || \
        printf "  ${RED}Product dir not found: %s${R}\n" "$prod_dir"
}

# ── Package product as encrypted archive ─────────────────────────────────
_package_product() {
    id=$(grep -v '^$' "$LISTINGS_DB" | \
        python3 -c "import sys,json; [print(json.loads(l)['id']+'  '+json.loads(l)['title']) for l in sys.stdin if l.strip()]" \
        2>/dev/null | fzf --prompt="Package > " 2>/dev/null | awk '{print $1}')
    [ -z "$id" ] && return
    prod_dir=$(grep "\"id\": \"$id\"" "$LISTINGS_DB" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('product_dir',''))" 2>/dev/null)
    out="$FORGE_DIR/${id}.tar.gz"
    tar czf "$out" -C "$prod_dir" . 2>/dev/null
    printf "\n  ${GRN}✓${R} Packaged: %s\n" "$out"
    printf "  ${GRY}Size: %s${R}\n" "$(du -h "$out" | cut -f1)"
    if command -v gpg >/dev/null 2>&1; then
        printf "  ${CYN}Encrypt with GPG? [y/N]${R} "
        old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null
        ans=$(dd bs=1 count=1 2>/dev/null | tr -d '\0'); stty "$old" 2>/dev/null
        printf "\n"
        if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
            old=$(stty -g 2>/dev/null); stty echo icanon 2>/dev/null
            printf "  GPG recipient (key ID or email) > "; IFS= read -r recip
            stty "$old" 2>/dev/null
            gpg --encrypt --recipient "$recip" "$out" 2>/dev/null && \
                printf "  ${GRN}✓${R} Encrypted: ${out}.gpg\n"
        fi
    fi
    printf "\n  Press any key..."; old=$(stty -g 2>/dev/null); stty -echo -icanon min 1 time 0 2>/dev/null; dd bs=1 count=1 2>/dev/null >/dev/null; stty "$old" 2>/dev/null
}

# ── Main loop ──────────────────────────────────────────────────────────────
old_stty=$(stty -g 2>/dev/null)
trap 'stty "$old_stty" 2>/dev/null; exit 0' INT TERM EXIT

while true; do
    _header
    _forge_status
    _list_listings
    printf "  ${ORG}${BOLD}[n]${R}  New listing\n"
    printf "  ${ORG}${BOLD}[e]${R}  Edit product files\n"
    printf "  ${ORG}${BOLD}[p]${R}  Publish listing → darknet store\n"
    printf "  ${ORG}${BOLD}[k]${R}  Package product (tar.gz + optional GPG)\n"
    printf "  ${ORG}${BOLD}[d]${R}  Open darknet publish manager\n"
    printf "  ${ORG}${BOLD}[q]${R}  Quit\n\n"
    printf "  ${GRY}Store: %s${R}\n\n" "$STORE_DIR"

    stty -echo -icanon min 1 time 0 2>/dev/null
    key=$(dd bs=1 count=1 2>/dev/null | tr -d '\0')
    stty "$old_stty" 2>/dev/null

    case "$key" in
        n|N) _new_listing ;;
        e|E) _edit_product ;;
        p|P) _publish_listing ;;
        k|K) _package_product ;;
        d|D) tmux new-window -n "DKPUB" "$SCRIPTS/nexus-darknet-publish.sh" ;;
        q|Q) exit 0 ;;
    esac
done

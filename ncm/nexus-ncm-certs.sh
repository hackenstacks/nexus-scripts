#!/bin/sh
# nexus-ncm-certs.sh — mTLS client certificate manager for NeXuS web server
#
# Usage:
#   nexus-ncm-certs.sh init              — create the CA (run once)
#   nexus-ncm-certs.sh issue <name>      — issue a client cert (laptop, phone, etc.)
#   nexus-ncm-certs.sh list              — list all issued certs and their status
#   nexus-ncm-certs.sh revoke <name>     — revoke a cert and rebuild the CRL
#   nexus-ncm-certs.sh install           — wire CA into the web server config
#   nexus-ncm-certs.sh uninstall         — remove client cert requirement
#   nexus-ncm-certs.sh show-ca           — print CA cert (for importing on devices)
#
# How mTLS works here:
#   - The server only accepts TLS connections from browsers holding a valid client cert
#   - Issue one cert per trusted device; import the .p12 into that device's browser
#   - Revoked certs are rejected at the TLS handshake — before any HTTP is served
#
# NeXuS: Sane · Simple · Secure · Stealthy · Beautiful

set -e

# ── Paths ─────────────────────────────────────────────────────────────────────
CA_DIR="${NCM_CA_DIR:-$HOME/vault/ncm-ca}"
CLIENT_DIR="$CA_DIR/clients"
INDEX="$CA_DIR/index.txt"
SERIAL="$CA_DIR/serial"
CRL="$CA_DIR/crl.pem"

PROXY_SCRIPT="${NEXUS_PROXY_SCRIPT:-$HOME/scripts/nexus-api-proxy.sh}"
SERVER_PY="${NEXUS_WEB_SERVER:-$HOME/Projects/nexus-web-server/nexus_web_server.py}"

DAYS_CA=3650      # CA validity: 10 years
DAYS_CLIENT=730   # client cert validity: 2 years

# ── Colours ───────────────────────────────────────────────────────────────────
R='\033[0m'; BOLD='\033[1m'
GRN='\033[38;5;82m'; CYN='\033[38;5;51m'
YLW='\033[38;5;226m'; RED='\033[38;5;196m'; DIM='\033[2m'

_ok()   { printf "${GRN}✓${R}  %s\n" "$*"; }
_info() { printf "${CYN}→${R}  %s\n" "$*"; }
_warn() { printf "${YLW}!${R}  %s\n" "$*"; }
_err()  { printf "${RED}✗${R}  %s\n" "$*" >&2; }
_die()  { _err "$*"; exit 1; }
_hdr()  { printf "\n${BOLD}${CYN}── %s ──${R}\n" "$*"; }

# ── OpenSSL config ────────────────────────────────────────────────────────────
_ca_conf() {
  cat > "$CA_DIR/openssl.cnf" << EOF
[ ca ]
default_ca = nexus_ca

[ nexus_ca ]
dir               = $CA_DIR
database          = $INDEX
serial            = $SERIAL
new_certs_dir     = $CLIENT_DIR
certificate       = $CA_DIR/ca.crt
private_key       = $CA_DIR/ca.key
crl               = $CRL
default_days      = $DAYS_CLIENT
default_crl_days  = 30
default_md        = sha256
policy            = nexus_policy
x509_extensions   = client_ext
copy_extensions   = copy
unique_subject    = no

[ nexus_policy ]
commonName        = supplied
organizationName  = optional

[ req ]
default_bits       = 2048
default_md         = sha256
distinguished_name = req_dn
prompt             = no

[ req_dn ]
CN = NeXuS NCM CA
O  = NeXuS Network

[ client_ext ]
basicConstraints = CA:FALSE
keyUsage         = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer

[ ca_ext ]
basicConstraints       = critical, CA:TRUE
keyUsage               = critical, keyCertSign, cRLSign
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always
EOF
}

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_init() {
  _hdr "Initialising NeXuS NCM Certificate Authority"

  [ -f "$CA_DIR/ca.crt" ] && _die "CA already exists at $CA_DIR — run 'list' to see certs"

  mkdir -p "$CA_DIR" "$CLIENT_DIR"
  chmod 700 "$CA_DIR"
  touch "$INDEX"
  printf '%s\n' "$(date +%Y%m%d)01" > "$SERIAL"

  _ca_conf

  _info "Generating CA key (4096-bit RSA)…"
  openssl genrsa -out "$CA_DIR/ca.key" 4096 2>/dev/null
  chmod 600 "$CA_DIR/ca.key"

  _info "Self-signing CA certificate (valid $DAYS_CA days)…"
  openssl req -new -x509 \
    -days "$DAYS_CA" \
    -key "$CA_DIR/ca.key" \
    -out "$CA_DIR/ca.crt" \
    -subj "/CN=NeXuS NCM CA/O=NeXuS Network" \
    -extensions ca_ext \
    -config "$CA_DIR/openssl.cnf" 2>/dev/null

  # Initial empty CRL
  openssl ca -gencrl \
    -config "$CA_DIR/openssl.cnf" \
    -out "$CRL" 2>/dev/null

  _ok "CA created: $CA_DIR/ca.crt"
  printf "\n${DIM}Next: issue your first client cert:${R}\n"
  printf "  %s issue laptop\n" "$0"
  printf "  %s issue phone\n\n" "$0"
}

cmd_issue() {
  name="$1"
  [ -z "$name" ] && _die "Usage: $0 issue <name>  (e.g. laptop, phone, anon)"
  # Sanitise name
  echo "$name" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,31}$' \
    || _die "Name must be alphanumeric + dash/underscore, max 32 chars"

  [ ! -f "$CA_DIR/ca.crt" ] && _die "CA not initialised — run '$0 init' first"

  out="$CLIENT_DIR/$name"
  [ -f "$out.p12" ] && _die "Cert '$name' already exists — revoke it first to re-issue"

  _hdr "Issuing client cert: $name"
  _ca_conf  # refresh config

  _info "Generating client key…"
  openssl genrsa -out "$out.key" 2048 2>/dev/null
  chmod 600 "$out.key"

  _info "Generating CSR…"
  openssl req -new \
    -key "$out.key" \
    -out "$out.csr" \
    -subj "/CN=$name/O=NeXuS Network" 2>/dev/null

  _info "Signing with CA (valid $DAYS_CLIENT days)…"
  openssl ca -batch \
    -config "$CA_DIR/openssl.cnf" \
    -in "$out.csr" \
    -out "$out.crt" \
    -days "$DAYS_CLIENT" 2>/dev/null

  _info "Exporting .p12 (browser import bundle)…"
  # Generate a random import password and save it alongside
  import_pass=$(openssl rand -hex 12)
  printf '%s\n' "$import_pass" > "$out.pass"
  chmod 600 "$out.pass"

  openssl pkcs12 -export \
    -inkey "$out.key" \
    -in "$out.crt" \
    -certfile "$CA_DIR/ca.crt" \
    -out "$out.p12" \
    -passout "pass:$import_pass" 2>/dev/null

  rm -f "$out.csr"

  _ok "Client cert issued: $out.p12"
  printf "\n${BOLD}Import password:${R} ${YLW}%s${R}\n" "$import_pass"
  printf "\n${DIM}Browser import:${R}\n"
  printf "  LibreWolf/Firefox: Settings → Privacy → Certificates → Your Certificates → Import\n"
  printf "  Chromium:          Settings → Privacy → Manage Certificates → Import\n"
  printf "  Android (Chrome):  Settings → Security → Install a Certificate → VPN & App User Certificate\n"
  printf "\n${DIM}Transfer to device:${R}\n"
  printf "  scp %s.p12 user@phone:/sdcard/\n" "$out"
  printf "  cat %s.p12 | base64  # paste into device terminal\n\n" "$out"
}

cmd_list() {
  _hdr "NeXuS NCM Client Certificates"

  [ ! -f "$CA_DIR/ca.crt" ] && { _warn "CA not initialised"; return; }

  # CA info
  expiry=$(openssl x509 -noout -enddate -in "$CA_DIR/ca.crt" 2>/dev/null | cut -d= -f2)
  printf "  ${BOLD}CA:${R} $CA_DIR/ca.crt  ${DIM}(expires %s)${R}\n\n" "$expiry"

  if [ ! -d "$CLIENT_DIR" ] || [ -z "$(ls "$CLIENT_DIR"/*.p12 2>/dev/null)" ]; then
    printf "  ${DIM}No client certs issued yet.${R}\n\n"
    return
  fi

  printf "  ${BOLD}%-20s  %-28s  %s${R}\n" "NAME" "EXPIRES" "STATUS"
  printf "  %s\n" "$(printf '%.0s─' $(seq 1 60))"

  for p12 in "$CLIENT_DIR"/*.p12; do
    n=$(basename "$p12" .p12)
    crt="$CLIENT_DIR/$n.crt"
    if [ -f "$crt" ]; then
      exp=$(openssl x509 -noout -enddate -in "$crt" 2>/dev/null | cut -d= -f2)
      # Check if revoked (appears in index with R prefix)
      if grep -q "^R.*CN=$n" "$INDEX" 2>/dev/null; then
        status="${RED}REVOKED${R}"
      else
        status="${GRN}VALID${R}"
      fi
    else
      exp="unknown"
      status="${YLW}CRT MISSING${R}"
    fi
    printf "  %-20s  %-28s  %b\n" "$n" "$exp" "$status"
  done
  printf "\n"
}

cmd_revoke() {
  name="$1"
  [ -z "$name" ] && _die "Usage: $0 revoke <name>"

  crt="$CLIENT_DIR/$name.crt"
  [ ! -f "$crt" ] && _die "No cert found for '$name'"

  _hdr "Revoking cert: $name"
  _ca_conf

  openssl ca -revoke "$crt" \
    -config "$CA_DIR/openssl.cnf" 2>/dev/null

  _info "Rebuilding CRL…"
  openssl ca -gencrl \
    -config "$CA_DIR/openssl.cnf" \
    -out "$CRL" 2>/dev/null

  # Remove .p12 and .pass so it can't be imported again
  rm -f "$CLIENT_DIR/$name.p12" "$CLIENT_DIR/$name.pass"

  _ok "Cert '$name' revoked and .p12 removed"
  _info "Restart the web server to enforce the new CRL"
}

cmd_install() {
  _hdr "Wiring CA into NeXuS web server"

  [ ! -f "$CA_DIR/ca.crt" ] && _die "CA not initialised — run '$0 init' first"

  # 1. Add --ca-cert support to nexus_web_server.py if not already there
  if ! grep -q "\-\-ca-cert" "$SERVER_PY" 2>/dev/null; then
    _info "Patching nexus_web_server.py to support --ca-cert…"
    python3 - "$SERVER_PY" "$CA_DIR/ca.crt" "$CRL" << 'PYEOF'
import sys, re
path = sys.argv[1]
text = open(path).read()

# 1. Add --ca-cert and --ca-crl args to argparse
arg_patch = '''    ap.add_argument("--ca-cert", default=None,
                    help="CA cert for mTLS — requires client cert on every connection")
    ap.add_argument("--ca-crl", default=None,
                    help="CRL file for revoked client certs (optional, rebuilt by nexus-ncm-certs.sh)")
'''
text = text.replace(
    '    ap.add_argument("--env",',
    arg_patch + '    ap.add_argument("--env",',
    1
)

# 2. Wire into SSL context setup (after ctx.load_cert_chain)
ssl_patch = '''
    if args.ca_cert:
        ca_path = Path(args.ca_cert)
        if ca_path.is_file():
            ctx.verify_mode = ssl.CERT_REQUIRED
            ctx.load_verify_locations(str(ca_path))
            if args.ca_crl:
                crl_path = Path(args.ca_crl)
                if crl_path.is_file():
                    ctx.verify_flags = ssl.VERIFY_CRL_CHECK_LEAF
                    ctx.load_verify_locations(cafile=None, cadata=None,
                                              capath=str(crl_path.parent))
            log(f"\\U0001f512 mTLS enabled — client cert required (CA: {ca_path.name})")
        else:
            log(f"\\u26a0\\ufe0f  --ca-cert not found: {ca_path} — proceeding without mTLS")
'''
text = text.replace(
    '    httpd = ThreadingHTTPServer(',
    ssl_patch + '\n    httpd = ThreadingHTTPServer(',
    1
)

open(path, 'w').write(text)
print("patched")
PYEOF
    _ok "nexus_web_server.py patched"
  else
    _info "nexus_web_server.py already supports --ca-cert"
  fi

  # 2. Add CA_CERT + CRL vars and --ca-cert flag to nexus-api-proxy.sh
  if ! grep -q "NCM_CA_CERT" "$PROXY_SCRIPT" 2>/dev/null; then
    _info "Patching nexus-api-proxy.sh…"
    # Insert CA_CERT variable after the KEY= line
    sed -i "s|KEY=\"\${NEXUS_WEB_KEY.*\"|&\nCA_CERT=\"\${NCM_CA_CERT:-$CA_DIR/ca.crt}\"\nCRL_FILE=\"\${NCM_CRL_FILE:-$CRL}\"|" \
      "$PROXY_SCRIPT" 2>/dev/null || true
    # Append --ca-cert to the cmd line
    sed -i 's|cmd="exec python3 $SERVER --root $ROOT --cert $CERT --key $KEY --port $PORT"|cmd="exec python3 $SERVER --root $ROOT --cert $CERT --key $KEY --port $PORT"\n    [ -f "$CA_CERT" ] \&\& cmd="$cmd --ca-cert $CA_CERT --ca-crl $CRL_FILE"|' \
      "$PROXY_SCRIPT" 2>/dev/null || true
    _ok "nexus-api-proxy.sh patched"
  else
    _info "nexus-api-proxy.sh already configured"
  fi

  _ok "mTLS install complete"
  printf "\n${DIM}To activate: restart the web server${R}\n"
  printf "  nexus-api-proxy.sh restart\n\n"
  printf "${DIM}Issue certs for each trusted device:${R}\n"
  printf "  %s issue laptop\n" "$0"
  printf "  %s issue phone\n\n" "$0"
}

cmd_uninstall() {
  _hdr "Removing client cert requirement"
  _warn "This allows ANY browser to connect without a cert"
  printf "Continue? [y/N]: "; read -r ans
  case "$ans" in y|Y) ;; *) exit 0 ;; esac

  # Remove --ca-cert from the proxy cmd if present
  if grep -q "ca-cert" "$PROXY_SCRIPT" 2>/dev/null; then
    sed -i '/ca-cert\|ca-crl\|NCM_CA_CERT\|NCM_CRL/d' "$PROXY_SCRIPT"
    _ok "nexus-api-proxy.sh updated"
  fi
  _info "Restart the web server to apply"
}

cmd_show_ca() {
  [ ! -f "$CA_DIR/ca.crt" ] && _die "CA not initialised"
  _hdr "CA Certificate (copy to trusted devices)"
  printf "${DIM}# Save as nexus-ncm-ca.crt and import into the device's trust store${R}\n"
  cat "$CA_DIR/ca.crt"
}

# ── Main ──────────────────────────────────────────────────────────────────────
cmd="${1:-help}"
shift 2>/dev/null || true

case "$cmd" in
  init)       cmd_init ;;
  issue)      cmd_issue "$@" ;;
  list)       cmd_list ;;
  revoke)     cmd_revoke "$@" ;;
  install)    cmd_install ;;
  uninstall)  cmd_uninstall ;;
  show-ca)    cmd_show_ca ;;
  help|--help|-h)
    printf "\n${BOLD}nexus-ncm-certs.sh${R} — mTLS client cert manager\n\n"
    printf "  ${CYN}init${R}           Create the CA (once per node)\n"
    printf "  ${CYN}issue <name>${R}   Issue a client cert (.p12 for browser import)\n"
    printf "  ${CYN}list${R}           Show all certs and their status\n"
    printf "  ${CYN}revoke <name>${R}  Revoke a cert and rebuild CRL\n"
    printf "  ${CYN}install${R}        Wire CA into web server (patches nexus-api-proxy.sh)\n"
    printf "  ${CYN}uninstall${R}      Remove client cert requirement\n"
    printf "  ${CYN}show-ca${R}        Print CA cert for device trust store import\n\n"
    printf "  CA lives at: ${DIM}%s${R}\n\n" "$CA_DIR"
    ;;
  *) _die "Unknown command: $cmd — run '$0 help'" ;;
esac

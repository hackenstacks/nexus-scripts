 cat << 'EOF' > ~/claude/scripts/styx-gen.sh
    2 #!/bin/sh
    3 # styx-gen.sh — NeXuS Prime Truth Token Generator
    4 # NeXuS: Sane • Simple • Secure • Stealthy • Beautiful
    5
    6 NODE_SECRET="${NODE_SECRET}"
    7
    8 _error() {
    9     echo "❌ Error: $1" >&2
   10     exit 1
   11 }
   12
   13 command -v openssl >/dev/null 2>&1 || _error "openssl not found"
   14 command -v bc >/dev/null 2>&1 || _error "bc not found"
   15
   16 if [ $# -lt 2 ]; then
   17     echo "Usage: [NODE_SECRET=...] $0 <contract_id> <sequence>"
   18     echo "Example: NODE_SECRET=mysecret $0 nexus:task:123 1"
   19     exit 1
   20 fi
   21
   22 [ -z "$NODE_SECRET" ] && _error "NODE_SECRET environment variable is required"
   23
   24 CONTRACT_ID="$1"
   25 SEQUENCE="$2"
   26
   27 BASE_HEX=$(echo -n "${CONTRACT_ID}${SEQUENCE}" | openssl dgst -sha256 -hmac
      "${NODE_SECRET}" | sed 's/^.*= //')
   28 BASE_DEC=$(echo "obase=10; ibase=16; $(echo $BASE_HEX | tr 'a-z' 'A-Z')" | bc)
   29
   30 CURRENT="$BASE_DEC"
   31 IS_EVEN=$(echo "$CURRENT % 2" | bc)
   32 if [ "$IS_EVEN" -eq 0 ]; then
   33     CURRENT=$(echo "$CURRENT + 1" | bc)
   34 fi
   35
   36 while true; do
   37     CHECK=$(openssl prime "$CURRENT" 2>/dev/null)
   38     if echo "$CHECK" | grep -q "is prime"; then
   39         echo "$CURRENT"
   40         exit 0
   41     fi
   42     CURRENT=$(echo "$CURRENT + 2" | bc)
   43 done
   44 EOF
   45


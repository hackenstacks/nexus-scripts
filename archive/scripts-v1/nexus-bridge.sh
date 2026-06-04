#!/bin/sh
# nexus-bridge.sh — NeXuS-to-DivaChain Bridge
# NeXuS: Sane • Simple • Secure • Stealthy • Beautiful
#
# <!-- NXS-FORGE-META
# id:           NXS-SCRIPT-BRIDGE-0001
# type:         SCRIPT
# principles:   Sane Simple Secure
# status:       ACTIVE
# -->

# Configuration
DIVA_HOST="${DIVA_HOST:-localhost}"
DIVA_PORT="${DIVA_PORT:-17468}"
BASE_URL="http://${DIVA_HOST}:${DIVA_PORT}"

_error() {
    echo "❌ Error: $1" >&2
    exit 1
}

_curl() {
    method="$1"; path="$2"; data="$3"; headers="$4"
    if [ -n "$data" ]; then
        curl -s -X "$method" "${BASE_URL}${path}" -H "Content-Type: application/json" $headers -d "$data"
    else
        curl -s -X "$method" "${BASE_URL}${path}" $headers
    fi
}

get_token() {
    token=$(_curl GET "/testnet/token")
    # Basic check if token looks like a hex string or alphanumeric
    if [ -z "$token" ] || [ ${#token} -lt 8 ]; then
        _error "Failed to fetch valid token from /testnet/token. Is DIVA running at $BASE_URL?"
    fi
    echo "$token"
}

case "$1" in
    status)
        _curl GET "/about"
        ;;
    peers)
        _curl GET "/network"
        ;;
    token)
        get_token
        ;;
    put)
        ns="$2"; data="$3"
        [ -z "$ns" ] || [ -z "$data" ] && _error "Usage: $0 put <ns> <data>"
        token=$(get_token)
        # NEW TX SCHEMA — April 2026
        payload="[{\"command\":\"data\",\"ns\":\"$ns\",\"d\":\"$data\"}]"
        
        # We use a custom header for the token
        res=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "${BASE_URL}/tx" \
            -H "Content-Type: application/json" \
            -H "diva-token-api: $token" \
            -d "$payload")
            
        if [ "$res" = "204" ] || [ "$res" = "202" ] || [ "$res" = "200" ]; then
            echo "✅ Transaction accepted ($res)"
        else
            _error "Transaction failed with status $res"
        fi
        ;;
    join)
        peer="$2"
        [ -z "$peer" ] && _error "Usage: $0 join <peer_addr>"
        
        # Ensure peer has protocol and port
        case "$peer" in
            http*) ;;
            *) peer="http://${peer}:17468" ;;
        esac
        
        # Fetch our local info
        about=$(_curl GET "/about")
        our_pubkey=$(echo "$about" | grep -o '"publicKey":"[^"]*"' | head -1 | cut -d'"' -f4)
        [ -z "$our_pubkey" ] && _error "Could not determine local public key from /about"
        
        # Determine our announce address
        our_http="${OUR_HTTP:-${DIVA_HOST}:${DIVA_PORT}}"
        
        echo "📣 Announcing to peer: $peer"
        # NEW JOIN ENDPOINT — April 2026
        res=$(curl -s -o /dev/null -w "%{http_code}" GET "${peer}/join/${our_pubkey}/${our_http}")
        
        if [ "$res" = "202" ] || [ "$res" = "200" ]; then
            echo "✅ Join request accepted ($res)"
        else
            _error "Join request failed with status $res"
        fi
        ;;
    watch)
        ns="$2"
        [ -z "$ns" ] && _error "Usage: $0 watch <ns>"
        
        echo "👁️ Watching namespace: $ns (Ctrl+C to stop)"
        while true; do
            # Using /state as it's the standard for querying records
            _curl GET "/state/$ns"
            echo ""
            sleep 5
        done
        ;;
    *)
        echo "Usage: $0 {status|peers|token|put|join|watch}"
        exit 1
        ;;
esac

#!/bin/bash
# 🛡️ NeXuS Quick Allow - Temporary Connection Approval
# Usage: ./nexus-quick-allow.sh <process> <destination> [duration_minutes]

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROCESS="$1"
DESTINATION="$2"
DURATION="${3:-60}"  # Default 1 hour

if [ $# -lt 2 ]; then
    echo -e "${RED}Usage: $0 <process> <destination> [duration_minutes]${NC}"
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 firefox github.com 60        # Allow Firefox to GitHub for 1 hour"
    echo -e "  $0 curl api.openai.com 30       # Allow curl to OpenAI for 30 minutes"
    echo -e "  $0 any google.com 120           # Allow any process to Google for 2 hours"
    exit 1
fi

RULES_DIR="/home/user/.nexus-security/containers/opensnitch/rules"
mkdir -p "$RULES_DIR"

RULE_FILE="$RULES_DIR/temp-allow-$(date +%s).json"

echo -e "${BLUE}🛡️ Creating temporary allow rule...${NC}"
echo -e "${YELLOW}Process: $PROCESS${NC}"
echo -e "${YELLOW}Destination: $DESTINATION${NC}" 
echo -e "${YELLOW}Duration: $DURATION minutes${NC}"

# Determine operator type based on process
if [ "$PROCESS" = "any" ]; then
    OPERATOR_TYPE="simple"
    OPERAND="dest.host"
    DATA="$DESTINATION"
else
    OPERATOR_TYPE="simple"
    OPERAND="process.path"
    DATA="/usr/bin/$PROCESS"
fi

# Create temporary rule with expiration
cat > "$RULE_FILE" << EOF
{
  "name": "NeXuS Temp Allow: $PROCESS -> $DESTINATION",
  "enabled": true,
  "action": "allow",
  "duration": "always",
  "operator": {
    "type": "$OPERATOR_TYPE",
    "operand": "$OPERAND", 
    "data": "$DATA"
  },
  "created": "$(date -Iseconds)",
  "expires": "$(date -d "+$DURATION minutes" -Iseconds)",
  "temp_rule": true
}
EOF

# Schedule rule deletion
(sleep $((DURATION * 60)) && rm -f "$RULE_FILE" && echo -e "${YELLOW}⏰ Temp rule expired: $PROCESS -> $DESTINATION${NC}") &

echo -e "${GREEN}✅ Temporary rule created: $RULE_FILE${NC}"
echo -e "${BLUE}🕒 Will expire in $DURATION minutes${NC}"

# Log the action
echo "$(date): TEMP_ALLOW $PROCESS -> $DESTINATION for $DURATION minutes" >> /home/user/.nexus-security/fortress.log

echo -e "${GREEN}🚀 Connection should now be allowed!${NC}"
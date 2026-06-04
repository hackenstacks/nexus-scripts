#!/bin/bash
# Test script for NeXuS Core Library
# Demonstrates the new standardized logging and UI features

# Source the core library
source "$(dirname "$0")/nexus-core.lib.sh"

# 1. Show the header
nexus::header "NeXuS Core Systems Test"

# 2. Test logging levels
nexus::info "Initializing system checks..."
sleep 0.5
nexus::success "Core library loaded successfully."
sleep 0.5
nexus::warn "Battery level is simulating 'Low' (Just kidding)."
sleep 0.5
nexus::error "An example error message (non-fatal)."

# 3. Test dependency checking
nexus::info "Checking for required tools..."
if nexus::check_dep "curl"; then
    nexus::success "curl is installed."
else
    nexus::warn "curl is missing."
fi

if nexus::check_dep "nonexistent_tool"; then
    nexus::success "Ghost tool found?"
else
    nexus::warn "Correctly identified missing tool 'nonexistent_tool'."
fi

# 4. Show paths
echo
nexus::info "Environment Paths:"
echo -e "   ${GREY}Home:${NC}    $NEXUS_HOME"
echo -e "   ${GREY}Config:${NC}  $NEXUS_CONFIG"
echo -e "   ${GREY}Logs:${NC}    $NEXUS_LOGS"
echo -e "   ${GREY}Temp:${NC}    $NEXUS_TMP"

# 5. Spinner test
echo
nexus::info "Testing spinner (3 seconds)..."
(sleep 3) &
nexus::spinner $!
nexus::success "Spinner test complete."

echo
nexus::info "Check $CURRENT_LOG_FILE for the log output of this session."
nexus::success "R&D Test Complete. We are ready for Phase 2."

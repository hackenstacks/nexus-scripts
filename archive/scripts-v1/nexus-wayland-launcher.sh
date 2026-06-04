#!/bin/bash

# NeXuS Wayland Display & Audio Launcher
# Launches Wayland compositor with proper display configuration and PipeWire audio

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${CYAN}[NeXuS]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Configuration variables
COMPOSITOR="labwc"  # Default compositor (labwc, sway, river, wayfire)
DISPLAY_NAME="wayland-0"
AUDIO_TIMEOUT=10

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --compositor|-c)
            COMPOSITOR="$2"
            shift 2
            ;;
        --display|-d)
            DISPLAY_NAME="$2"
            shift 2
            ;;
        --help|-h)
            echo "🔥 NeXuS Wayland Launcher"
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -c, --compositor  Set compositor (labwc, sway, river, wayfire)"
            echo "  -d, --display     Set display name (default: wayland-0)"
            echo "  -h, --help        Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                    # Launch with labwc"
            echo "  $0 -c sway           # Launch with sway"
            echo "  $0 -c river          # Launch with river"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_status "🔥 Starting NeXuS Wayland Environment"

# Check if already running in Wayland
if [[ -n "$WAYLAND_DISPLAY" ]]; then
    print_warning "Wayland display already active: $WAYLAND_DISPLAY"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Set up XDG runtime directory
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
if [[ ! -d "$XDG_RUNTIME_DIR" ]]; then
    print_error "XDG_RUNTIME_DIR does not exist: $XDG_RUNTIME_DIR"
    exit 1
fi

print_success "XDG runtime directory: $XDG_RUNTIME_DIR"

# Check if compositor exists
if ! command -v "$COMPOSITOR" >/dev/null 2>&1; then
    print_error "Compositor '$COMPOSITOR' not found"
    print_status "Available compositors:"
    for comp in labwc sway river wayfire hyprland; do
        if command -v "$comp" >/dev/null 2>&1; then
            echo "  - $comp"
        fi
    done
    exit 1
fi

print_success "Found compositor: $COMPOSITOR"

# Kill existing compositor instances
print_status "Stopping existing compositor instances..."
pkill -f "$COMPOSITOR" 2>/dev/null
sleep 1

# Check for EGL support
check_egl_support() {
    print_status "🎮 Checking EGL/GPU acceleration support..."
    
    local egl_available=false
    local gpu_info=""
    
    # Check for EGL
    if command -v eglinfo >/dev/null 2>&1; then
        if eglinfo >/dev/null 2>&1; then
            egl_available=true
            print_success "EGL support detected"
        fi
    fi
    
    # Check for GPU drivers
    if [[ -e /dev/dri/card0 ]]; then
        gpu_info=$(lspci | grep -i vga | head -1 | cut -d: -f3- | xargs)
        print_success "GPU detected: $gpu_info"
    fi
    
    # Check for OpenGL
    if command -v glxinfo >/dev/null 2>&1; then
        local gl_vendor=$(glxinfo 2>/dev/null | grep "OpenGL vendor" | cut -d: -f2- | xargs)
        if [[ -n "$gl_vendor" ]]; then
            print_success "OpenGL vendor: $gl_vendor"
        fi
    fi
    
    return $([ "$egl_available" = true ] && echo 0 || echo 1)
}

# Set up Wayland environment variables with EGL
setup_wayland_environment() {
    local use_egl=$1
    
    export WAYLAND_DISPLAY="$DISPLAY_NAME"
    export XDG_SESSION_TYPE="wayland"
    export XDG_CURRENT_DESKTOP="$COMPOSITOR"
    export QT_QPA_PLATFORM="wayland"
    export GDK_BACKEND="wayland"
    export MOZ_ENABLE_WAYLAND=1
    export CLUTTER_BACKEND="wayland"
    export SDL_VIDEODRIVER="wayland"
    
    if [[ "$use_egl" == "true" ]]; then
        # Enable EGL/hardware acceleration
        export EGL_PLATFORM="wayland"
        export QT_QPA_PLATFORM="wayland-egl"
        export GBM_BACKENDS_PATH="/usr/lib/gbm"
        export WLR_RENDERER="gles2"
        export WLR_NO_HARDWARE_CURSORS=1  # Fallback for some GPUs
        
        # NVIDIA specific (if present)
        if lspci | grep -i nvidia >/dev/null 2>&1; then
            export GBM_BACKEND="nvidia-drm"
            export __GLX_VENDOR_LIBRARY_NAME="nvidia"
            export WLR_DRM_NO_ATOMIC=1
        fi
        
        print_success "Wayland-EGL environment configured (hardware acceleration)"
        print_status "  EGL_PLATFORM=$EGL_PLATFORM"
        print_status "  QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
    else
        print_warning "Using software rendering (EGL disabled)"
    fi
    
    print_status "Wayland environment configured:"
    print_status "  WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    print_status "  XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
}

# Start PipeWire audio system
start_pipewire() {
    print_status "🎵 Setting up PipeWire audio..."
    
    # Kill existing audio processes
    pkill -f pipewire 2>/dev/null
    pkill -f wireplumber 2>/dev/null
    pkill -f pipewire-pulse 2>/dev/null
    sleep 1
    
    # Start PipeWire services
    pipewire &
    PIPEWIRE_PID=$!
    sleep 1
    
    wireplumber &
    WIREPLUMBER_PID=$!
    sleep 1
    
    pipewire-pulse &
    PULSE_PID=$!
    sleep 1
    
    # Wait for audio system to initialize
    print_status "Waiting for PipeWire to initialize..."
    local timeout=$AUDIO_TIMEOUT
    while [[ $timeout -gt 0 ]]; do
        if pactl info >/dev/null 2>&1; then
            print_success "PipeWire audio system ready"
            return 0
        fi
        sleep 1
        ((timeout--))
        echo -n "."
    done
    
    print_warning "PipeWire may not be fully ready, continuing anyway..."
    return 0
}

# Start compositor with EGL support and fallback
start_compositor() {
    local use_egl=$1
    local attempt_name=""
    
    if [[ "$use_egl" == "true" ]]; then
        attempt_name="$COMPOSITOR with EGL acceleration"
    else
        attempt_name="$COMPOSITOR with software rendering"
    fi
    
    print_status "🖥️ Starting $attempt_name..."
    
    case "$COMPOSITOR" in
        "labwc")
            labwc &
            COMPOSITOR_PID=$!
            ;;
        "sway")
            sway &
            COMPOSITOR_PID=$!
            ;;
        "river")
            river &
            COMPOSITOR_PID=$!
            ;;
        "wayfire")
            wayfire &
            COMPOSITOR_PID=$!
            ;;
        "hyprland")
            Hyprland &
            COMPOSITOR_PID=$!
            ;;
        *)
            print_error "Unsupported compositor: $COMPOSITOR"
            return 1
            ;;
    esac
    
    # Wait for compositor to start
    local timeout=10
    while [[ $timeout -gt 0 ]]; do
        if [[ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]]; then
            if [[ "$use_egl" == "true" ]]; then
                print_success "Compositor started with hardware acceleration"
            else
                print_success "Compositor started with software rendering"
            fi
            return 0
        fi
        sleep 1
        ((timeout--))
        echo -n "."
    done
    
    print_error "$attempt_name failed to start"
    return 1
}

# Test audio functionality
test_audio() {
    print_status "🎵 Testing audio functionality..."
    
    if command -v pactl >/dev/null 2>&1; then
        if pactl info >/dev/null 2>&1; then
            print_success "PulseAudio/PipeWire connection working"
            
            # Test audio output
            if command -v speaker-test >/dev/null 2>&1; then
                print_status "Testing audio output (2 seconds)..."
                timeout 2s speaker-test -t sine -f 1000 -l 1 >/dev/null 2>&1 || true
                print_success "Audio test completed"
            fi
        else
            print_warning "Audio system not responding"
        fi
    else
        print_warning "pactl not available for audio testing"
    fi
}

# Display information
show_info() {
    print_status "🔥 NeXuS Wayland Environment Ready!"
    echo ""
    echo "Environment:"
    echo "  Compositor: $COMPOSITOR (PID: $COMPOSITOR_PID)"
    echo "  Display: $WAYLAND_DISPLAY"
    echo "  Socket: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    echo ""
    echo "Audio:"
    echo "  PipeWire: $PIPEWIRE_PID"
    echo "  WirePlumber: $WIREPLUMBER_PID"
    echo "  PipeWire-Pulse: $PULSE_PID"
    echo ""
    echo "Test commands:"
    echo "  chromium --enable-features=WebSpeechAPI https://localhost:8443/"
    echo "  qterminal"
    echo "  firefox"
    echo ""
    echo "Press Ctrl+C to stop all services"
}

# Cleanup function
cleanup() {
    print_status "🛑 Stopping NeXuS Wayland environment..."
    
    # Kill compositor
    if [[ -n "$COMPOSITOR_PID" ]]; then
        kill "$COMPOSITOR_PID" 2>/dev/null
    fi
    pkill -f "$COMPOSITOR" 2>/dev/null
    
    # Kill audio processes
    if [[ -n "$PIPEWIRE_PID" ]]; then kill "$PIPEWIRE_PID" 2>/dev/null; fi
    if [[ -n "$WIREPLUMBER_PID" ]]; then kill "$WIREPLUMBER_PID" 2>/dev/null; fi
    if [[ -n "$PULSE_PID" ]]; then kill "$PULSE_PID" 2>/dev/null; fi
    
    print_success "Cleanup completed"
    exit 0
}

# Set up signal handlers
trap cleanup INT TERM

# Main execution
main() {
    local use_egl="false"
    
    # Check EGL support and decide on acceleration
    if check_egl_support; then
        use_egl="true"
        print_status "🚀 Using hardware acceleration (EGL) as default"
    else
        print_warning "EGL not available, using software rendering"
    fi
    
    # Set up environment
    setup_wayland_environment "$use_egl"
    
    # Start audio system
    start_pipewire
    
    # Try to start compositor with EGL first, fallback to software
    if [[ "$use_egl" == "true" ]]; then
        if ! start_compositor "true"; then
            print_warning "EGL acceleration failed, falling back to software rendering..."
            
            # Kill any failed compositor attempts
            pkill -f "$COMPOSITOR" 2>/dev/null
            sleep 1
            
            # Reconfigure for software rendering
            setup_wayland_environment "false"
            
            # Try again with software rendering
            if ! start_compositor "false"; then
                print_error "Failed to start compositor with software rendering"
                cleanup
                exit 1
            fi
        fi
    else
        # Direct software rendering
        if ! start_compositor "false"; then
            print_error "Failed to start compositor"
            cleanup
            exit 1
        fi
    fi
    
    # Test audio
    test_audio
    
    # Show information
    show_info
    
    # Wait for compositor to exit
    wait "$COMPOSITOR_PID"
    
    print_status "Compositor exited, cleaning up..."
    cleanup
}

# Check for dependencies
check_deps() {
    local missing=()
    
    # Check essential commands
    for cmd in pipewire wireplumber pipewire-pulse pactl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        print_status "Install with: doas apk add pipewire wireplumber pipewire-pulse"
        exit 1
    fi
}

# Run dependency check
check_deps

# Start main function
main
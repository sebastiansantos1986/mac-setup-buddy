#!/bin/bash

# ============================================================================
# Mac Setup Buddy - Popup Test Launcher
# ============================================================================
#
# Purpose:
#   Quickly launch the real Mac Setup Buddy popup windows with good test sizes,
#   blur enabled, and sample data. Debug mode is enabled by default so this can
#   be used for UI/authentication testing without running production installs.
#
# Usage:
#   ./test-popups.sh
#   ./test-popups.sh welcome
#   ./test-popups.sh install
#   ./test-popups.sh all
#
# Optional:
#   MAC_SETUP_BUDDY_APP="/path/to/Mac Setup Buddy" ./test-popups.sh welcome
#
# ============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# CONFIGURATION
# ============================================================================

APP_NAME="Mac Setup Buddy"
APP_BINARY="${MAC_SETUP_BUDDY_APP:-}"

# Azure AD / Microsoft Graph Credentials
#
# These are intentionally blank by default so secrets are never committed.
# For Jamf, pass the client secret as parameter 4. For local testing, export
# the values before running this script.
MS_GRAPH_CLIENT_ID="${MS_GRAPH_CLIENT_ID:-}"
MS_GRAPH_TENANT_ID="${MS_GRAPH_TENANT_ID:-}"
# MS_GRAPH_CLIENT_SECRET="${4:-}"
MS_GRAPH_CLIENT_SECRET="${4:-${MS_GRAPH_CLIENT_SECRET:-}}"

# Debug Mode
#
# Keep this true for popup/authentication testing. The launcher uses simulated
# install data in debug mode and does not run production install commands.
DEBUG_MODE="${DEBUG_MODE:-true}"

DEFAULT_BLUR="true"
PERSISTENT_BLUR="${PERSISTENT_BLUR:-true}"
AUTO_CLOSE_SECONDS="${AUTO_CLOSE_SECONDS:-8}"
BLUR_STARTED_BY_SCRIPT="false"
BLUR_PID=""

UI_WIDTH_WELCOME=900
UI_HEIGHT_WELCOME=700
UI_WIDTH_AUTH=900
UI_HEIGHT_AUTH=700
UI_WIDTH_NETWORK=920
UI_HEIGHT_NETWORK=720
UI_WIDTH_INSTALL=1200
UI_HEIGHT_INSTALL=850
UI_WIDTH_ERROR=1000
UI_HEIGHT_ERROR=760
UI_WIDTH_COMPLETE=1050
UI_HEIGHT_COMPLETE=760
UI_WIDTH_NOTIFICATION=700
UI_HEIGHT_NOTIFICATION=540
UI_WIDTH_AAD=760
UI_HEIGHT_AAD=560

SAMPLE_EMAIL="sebastian.santos@example.com"
SAMPLE_USER_NAME="Santos, Sebastian"
SAMPLE_DEPARTMENT="IT - User Experience"
SAMPLE_TITLE="Director, End User Services"
SAMPLE_ASSET="MBA-226TCF"
SAMPLE_DEVICE_NAME="MBA-226TCF"
SAMPLE_DEVICE_MODEL="MacBook Air"
SAMPLE_SERIAL="LNHX226TCF"
SAMPLE_MACOS="15.7.3"
SAMPLE_NETWORK_HOSTS="https://apple.com"

SAMPLE_POLICIES="rosetta|install-rosetta|Rosetta 2|Apple Silicon Support|system|pending;identity|install-identity-agent|Identity Agent|Authentication service|security|pending;teams|install-teams|Microsoft Teams|Collaboration platform|application|pending;chrome|install-chrome|Google Chrome|Browser|application|pending"

# ============================================================================
# HELPERS
# ============================================================================

find_app_binary() {
    local candidates=(
        "$APP_BINARY"
        "$SCRIPT_DIR/build/DerivedData/Build/Products/Debug/Mac Setup Buddy.app/Contents/MacOS/Mac Setup Buddy"
        "$SCRIPT_DIR/build/DerivedData/Build/Products/Release/Mac Setup Buddy.app/Contents/MacOS/Mac Setup Buddy"
        "$SCRIPT_DIR/Mac Setup Buddy.app/Contents/MacOS/Mac Setup Buddy"
        "/Applications/Utilities/Mac Setup Buddy.app/Contents/MacOS/Mac Setup Buddy"
        "/Applications/Mac Setup Buddy.app/Contents/MacOS/Mac Setup Buddy"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            APP_BINARY="$candidate"
            return 0
        fi
    done

    return 1
}

print_header() {
    clear
    echo "============================================================"
    echo " Mac Setup Buddy - Popup Test Launcher"
    echo "============================================================"
    echo " App: ${APP_BINARY:-not found yet}"
    echo " Debug Mode: $DEBUG_MODE"
    echo " Blur: $DEFAULT_BLUR"
    echo " Persistent Blur: $PERSISTENT_BLUR"
    echo ""
}

usage() {
    cat <<EOF
Usage:
  ./test-popups.sh
  ./test-popups.sh welcome
  ./test-popups.sh auth
  ./test-popups.sh network
  ./test-popups.sh install
  ./test-popups.sh error
  ./test-popups.sh complete
  ./test-popups.sh notification
  ./test-popups.sh aad
  ./test-popups.sh preview
  ./test-popups.sh all

EOF
}

require_app() {
    if ! find_app_binary; then
        echo "Could not find a built $APP_NAME app."
        echo ""
        echo "Build it in Xcode first, or point to it manually:"
        echo "  MAC_SETUP_BUDDY_APP=\"/path/to/Mac Setup Buddy\" ./test-popups.sh"
        exit 1
    fi
}

blur_args() {
    if [[ "$DEFAULT_BLUR" == "true" && "$PERSISTENT_BLUR" == "true" ]]; then
        echo "--blur-mode persistent"
    elif [[ "$DEFAULT_BLUR" == "true" ]]; then
        echo "--enable-blur"
    fi
}

start_blur_background() {
    require_app

    if [[ "$DEFAULT_BLUR" != "true" || "$PERSISTENT_BLUR" != "true" ]]; then
        return 0
    fi

    if [[ -n "$BLUR_PID" ]] && kill -0 "$BLUR_PID" 2>/dev/null; then
        return 0
    fi

    echo "Starting persistent blur background..."
    "$APP_BINARY" --blur-start --background blur &
    BLUR_PID=$!
    BLUR_STARTED_BY_SCRIPT="true"
    sleep 1
}

stop_blur_background() {
    if [[ "$BLUR_STARTED_BY_SCRIPT" != "true" ]]; then
        return 0
    fi

    echo "Stopping persistent blur background..."
    "$APP_BINARY" --blur-stop >/dev/null 2>&1 || true

    if [[ -n "$BLUR_PID" ]] && kill -0 "$BLUR_PID" 2>/dev/null; then
        kill "$BLUR_PID" 2>/dev/null || true
        sleep 0.4
    fi

    BLUR_PID=""
    BLUR_STARTED_BY_SCRIPT="false"
}

launch_popup() {
    require_app
    start_blur_background
    echo ""
    echo "Launching: $*"
    [[ "$DEBUG_MODE" == "true" ]] && echo "Debug mode is active: no production installs will run."
    echo ""
    "$APP_BINARY" "$@"
}

launch_popup_timed() {
    require_app
    start_blur_background
    local label="$1"
    shift

    echo "Showing $label for ${AUTO_CLOSE_SECONDS}s..."
    [[ "$DEBUG_MODE" == "true" ]] && echo "Debug mode is active: no production installs will run."
    "$APP_BINARY" "$@" &
    local pid=$!
    sleep "$AUTO_CLOSE_SECONDS"

    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        sleep 0.4
    fi
}

run_single_popup() {
    trap stop_blur_background EXIT INT TERM
    "$@"
    stop_blur_background
    trap - EXIT INT TERM
}

# ============================================================================
# SCREEN LAUNCHERS
# ============================================================================

show_welcome() {
    launch_popup \
        --screen welcome \
        $(blur_args) \
        --width "$UI_WIDTH_WELCOME" \
        --height "$UI_HEIGHT_WELCOME" \
        --title "Welcome to Mac Setup Buddy" \
        --subtitle "Device Setup & Configuration" \
        --message "Let's get your Mac configured for secure access. This process will verify your account, prepare your device, and install required apps." \
        --buttonText "Begin Setup"
}

show_auth() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo "Authentication popup test is using sample identity data."
    elif [[ -z "$MS_GRAPH_CLIENT_ID" || -z "$MS_GRAPH_TENANT_ID" || -z "$MS_GRAPH_CLIENT_SECRET" ]]; then
        echo "WARNING: Microsoft Graph credentials are not fully configured."
        echo "Set MS_GRAPH_CLIENT_ID, MS_GRAPH_TENANT_ID, and MS_GRAPH_CLIENT_SECRET."
    fi

    launch_popup \
        --screen auth \
        $(blur_args) \
        --width "$UI_WIDTH_AUTH" \
        --height "$UI_HEIGHT_AUTH" \
        --email "$SAMPLE_EMAIL" \
        --placeholder "$SAMPLE_EMAIL"
}

show_network() {
    launch_popup \
        --screen network-check \
        $(blur_args) \
        --width "$UI_WIDTH_NETWORK" \
        --height "$UI_HEIGHT_NETWORK" \
        --network-hosts "$SAMPLE_NETWORK_HOSTS"
}

show_install() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo "Install popup test is using simulated policy data."
    fi

    launch_popup \
        --screen install \
        $(blur_args) \
        --width "$UI_WIDTH_INSTALL" \
        --height "$UI_HEIGHT_INSTALL" \
        --title "Software Deployment" \
        --subtitle "Installing required components" \
        --policies "$SAMPLE_POLICIES" \
        --enableLogMonitor true
}

show_error() {
    launch_popup \
        --screen error \
        $(blur_args) \
        --width "$UI_WIDTH_ERROR" \
        --height "$UI_HEIGHT_ERROR"
}

show_complete() {
    launch_popup \
        --screen complete \
        $(blur_args) \
        --width "$UI_WIDTH_COMPLETE" \
        --height "$UI_HEIGHT_COMPLETE" \
        --userName "$SAMPLE_USER_NAME" \
        --email "$SAMPLE_EMAIL" \
        --department "$SAMPLE_DEPARTMENT" \
        --title "$SAMPLE_TITLE" \
        --assetTag "$SAMPLE_ASSET" \
        --deviceName "$SAMPLE_DEVICE_NAME" \
        --deviceModel "$SAMPLE_DEVICE_MODEL" \
        --serialNumber "$SAMPLE_SERIAL" \
        --osVersion "$SAMPLE_MACOS" \
        --isEncrypted true
}

show_notification() {
    launch_popup \
        --screen notification \
        $(blur_args) \
        --width "$UI_WIDTH_NOTIFICATION" \
        --height "$UI_HEIGHT_NOTIFICATION" \
        --title "Setup Notice" \
        --message "This is a real notification popup test." \
        --icon "info.circle.fill" \
        --buttons "Continue,Cancel"
}

show_aad() {
    launch_popup \
        --screen aad \
        $(blur_args) \
        --width "$UI_WIDTH_AAD" \
        --height "$UI_HEIGHT_AAD" \
        --email "$SAMPLE_EMAIL" \
        --message "Verifying account details" \
        --autoProgress true \
        --stepDuration 1.2
}

show_preview() {
    launch_popup --preview-mode
}

show_all() {
    require_app
    local stop_blur_when_done="false"
    if [[ "$BLUR_STARTED_BY_SCRIPT" != "true" ]]; then
        stop_blur_when_done="true"
        trap stop_blur_background EXIT INT TERM
    fi

    start_blur_background
    echo "Running all real popup screens."
    echo "Each screen will auto-close after ${AUTO_CLOSE_SECONDS}s."
    echo ""

    launch_popup_timed "Welcome" --screen welcome $(blur_args) --width "$UI_WIDTH_WELCOME" --height "$UI_HEIGHT_WELCOME"
    launch_popup_timed "Authentication" --screen auth $(blur_args) --width "$UI_WIDTH_AUTH" --height "$UI_HEIGHT_AUTH" --email "$SAMPLE_EMAIL"
    launch_popup_timed "Network Required" --screen network-check $(blur_args) --width "$UI_WIDTH_NETWORK" --height "$UI_HEIGHT_NETWORK" --network-hosts "$SAMPLE_NETWORK_HOSTS"
    launch_popup_timed "Software Deployment" --screen install $(blur_args) --width "$UI_WIDTH_INSTALL" --height "$UI_HEIGHT_INSTALL" --policies "$SAMPLE_POLICIES"
    launch_popup_timed "Error Recovery" --screen error $(blur_args) --width "$UI_WIDTH_ERROR" --height "$UI_HEIGHT_ERROR"
    launch_popup_timed "Setup Complete" --screen complete $(blur_args) --width "$UI_WIDTH_COMPLETE" --height "$UI_HEIGHT_COMPLETE" --userName "$SAMPLE_USER_NAME" --email "$SAMPLE_EMAIL" --department "$SAMPLE_DEPARTMENT" --title "$SAMPLE_TITLE" --assetTag "$SAMPLE_ASSET" --deviceName "$SAMPLE_DEVICE_NAME" --deviceModel "$SAMPLE_DEVICE_MODEL" --serialNumber "$SAMPLE_SERIAL" --osVersion "$SAMPLE_MACOS" --isEncrypted true

    echo ""
    echo "All popup tests completed."

    if [[ "$stop_blur_when_done" == "true" ]]; then
        stop_blur_background
        trap - EXIT INT TERM
    fi
}

# ============================================================================
# MENU
# ============================================================================

menu() {
    require_app
    trap stop_blur_background EXIT INT TERM
    start_blur_background

    while true; do
        print_header
        cat <<EOF
Choose a popup to test:

  1. Welcome
  2. User Authentication
  3. Network Required
  4. Software Deployment
  5. Error Recovery
  6. Setup Complete
  7. Notification
  8. AAD Progress
  9. Preview Gallery
  A. Run All

  Q. Quit

EOF
        read -r -p "Selection: " choice

        case "$choice" in
            1) show_welcome ;;
            2) show_auth ;;
            3) show_network ;;
            4) show_install ;;
            5) show_error ;;
            6) show_complete ;;
            7) show_notification ;;
            8) show_aad ;;
            9) show_preview ;;
            [Aa]) show_all ;;
            [Qq])
                stop_blur_background
                trap - EXIT INT TERM
                exit 0
                ;;
            *) echo "Invalid selection"; sleep 1 ;;
        esac

        echo ""
        read -r -p "Press Return to go back to the menu..."
    done
}

case "${1:-menu}" in
    menu) menu ;;
    welcome) run_single_popup show_welcome ;;
    auth|authentication) run_single_popup show_auth ;;
    network|network-check) run_single_popup show_network ;;
    install|progress|deployment) run_single_popup show_install ;;
    error|recovery) run_single_popup show_error ;;
    complete|completion|done) run_single_popup show_complete ;;
    notification|notify) run_single_popup show_notification ;;
    aad|aad-progress) run_single_popup show_aad ;;
    preview) run_single_popup show_preview ;;
    all) show_all ;;
    help|-h|--help) usage ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
esac

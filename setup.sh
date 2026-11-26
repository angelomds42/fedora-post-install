#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly ROOT

source "$ROOT/lib/common.sh"
source "$ROOT/lib/pkg.sh"

# Module definitions - single source of truth
declare -A MODULE_DESC=(
    [system]="DNF tuning, system upgrade, firmware"
    [repos]="Third-party repos (RPM Fusion, Flathub, Chrome, VS Code, Brave, Librewolf)"
    [media]="Multimedia codecs and OpenH264"
    [drivers]="GPU drivers (AMD/Intel) with auto-detection"
    [apps]="RPM and Flatpak packages from configured lists"
    [fonts]="Google Sans Flex as default UI font"
    [cleanup]="Remove orphaned packages and clean caches"
)
readonly MODULE_DESC

# Module order matters for dependencies
MODULES=(system repos media drivers apps fonts cleanup)
readonly MODULES

DRY_RUN=false
CONFIG_FILE=
ONLY=
SKIP=
STATE_DIR=
SUDO_KEEPALIVE_PID=
SELECTED=()
FAILED=()
AUTO_YES=false
INTERACTIVE=true
VERIFY_ONLY=false

usage() {
    cat <<USAGE
${C_BOLD}Usage:${C_RESET} ${0##*/} [options]

${C_BOLD}Modes:${C_RESET}
  --verify              Verify installation completed successfully
  -y, --yes             Answer yes to all prompts (non-interactive)
  -n, --dry-run         Print commands without executing

${C_BOLD}Modules:${C_RESET}
  -o, --only a,b        Run only the given modules
  -s, --skip a,b        Skip the given modules
  -l, --list            List available modules

${C_BOLD}Configuration:${C_RESET}
  -c, --config FILE     Load config file after config/default.conf
  -h, --help            Show this help

${C_BOLD}Examples:${C_RESET}
  ${0##*/}                    # Full interactive installation
  ${0##*/} -y                 # Automated installation (CI/CD)
  ${0##*/} --verify           # Verify existing installation
  ${0##*/} -o system,apps     # Only system and apps
  ${0##*/} -s fonts,cleanup   # Skip fonts and cleanup
USAGE
}

list_modules() {
    local m
    step "Available modules:"
    for m in "${MODULES[@]}"; do
        printf "  ${C_BOLD}%-10s${C_RESET} %s\n" "$m" "${MODULE_DESC[$m]}"
    done
    echo
}

# Validate that all declared modules have implementations
validate_modules() {
    local m
    for m in "${MODULES[@]}"; do
        [[ -f $ROOT/modules/$m.sh ]] || die "module file not found: modules/$m.sh"
        [[ -n ${MODULE_DESC[$m]:-} ]] || die "module description missing: $m"
    done
}

confirm() {
    local prompt=$1 default=${2:-Y}
    [[ $AUTO_YES == true ]] && return 0
    [[ $INTERACTIVE == false ]] && return 1
    read -rp "$prompt [$default/n] " ans
    [[ ${ans:-$default} =~ ^[Yy]$ ]]
}

parse_args() {
    while (( $# )); do
        case $1 in
            --verify)       VERIFY_ONLY=true; shift ;;
            -y|--yes)       AUTO_YES=true; INTERACTIVE=false; shift ;;
            -n|--dry-run)   DRY_RUN=true; shift ;;
            -o|--only)      ONLY=${2:?}; shift 2 ;;
            -s|--skip)      SKIP=${2:?}; shift 2 ;;
            -c|--config)    CONFIG_FILE=${2:?}; shift 2 ;;
            -l|--list)      list_modules; exit 0 ;;
            -h|--help)      usage; exit 0 ;;
            *)              usage >&2; die "unknown option: $1" ;;
        esac
    done
}

load_config() {
    [[ -f $ROOT/config/default.conf ]] || die "default config not found"
    source "$ROOT/config/default.conf"
    if [[ -n $CONFIG_FILE ]]; then
        [[ -f $CONFIG_FILE ]] || die "config not found: $CONFIG_FILE"
        source "$CONFIG_FILE"
    elif [[ -f $ROOT/config/local.conf ]]; then
        source "$ROOT/config/local.conf"
    fi
}

check_environment() {
    if ! is_true "$DRY_RUN"; then
        local id
        id=$(. /etc/os-release && echo "$ID")
        [[ $id == fedora ]] || die "Fedora only (detected: $id)"
    fi
    (( EUID != 0 )) || die "Run as regular user; sudo is used when needed"
}

select_modules() {
    local m
    local -a only=() skip=()
    [[ -n $ONLY ]] && IFS=, read -ra only <<<"$ONLY"
    [[ -n $SKIP ]] && IFS=, read -ra skip <<<"$SKIP"

    for m in "${only[@]}" "${skip[@]}"; do
        contains "$m" "${MODULES[@]}" || die "unknown module: $m"
    done

    for m in "${MODULES[@]}"; do
        (( ${#only[@]} )) && ! contains "$m" "${only[@]}" && continue
        contains "$m" "${skip[@]}" && continue
        SELECTED+=("$m")
    done

    (( ${#SELECTED[@]} > 0 )) || die "no modules selected"
}

start_sudo_keepalive() {
    sudo -v
    while kill -0 "$$" 2>/dev/null; do
        sudo -n true
        sleep 50
    done &
    SUDO_KEEPALIVE_PID=$!
    # Ensure keepalive is cleaned up on exit
    trap 'cleanup_sudo_keepalive' EXIT
}

cleanup_sudo_keepalive() {
    [[ -n $SUDO_KEEPALIVE_PID ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}

cleanup_state() {
    cleanup_sudo_keepalive
    rm -rf "$STATE_DIR"
}

run_module() {
    local name=$1
    step "$name: ${MODULE_DESC[$name]}"
    (
        set -e
        trap 'err "failed at ${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]} (${FUNCNAME[1]:-main})"' ERR
        source "$ROOT/modules/$name.sh"
        "${name}::run"
    )
}

# Check if a repo is enabled in config
is_repo_enabled() {
    local repo=$1
    [[ " ${REPOS[*]:-} " =~ " $repo " ]]
}

# Check if a package list is enabled in config
is_list_enabled() {
    local type=$1 list=$2
    local -n var_ref="${type^^}_LISTS"
    [[ " ${var_ref[*]:-} " =~ " $list " ]]
}

verify_module() {
    local name=$1
    local status=0

    case $name in
        system)
            rpm -q dnf5-plugins pciutils &>/dev/null || { err "system: base packages missing"; status=1; }
            is_true "$UPDATE_FIRMWARE" && ! command -v fwupdmgr &>/dev/null && { err "system: fwupdmgr not installed"; status=1; }
            ;;
        repos)
            is_repo_enabled rpmfusion && rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null || { err "repos: RPM Fusion missing"; status=1; }
            is_repo_enabled flathub && flatpak remote-list | grep -q flathub || { err "repos: Flathub not configured"; status=1; }
            is_repo_enabled chrome && [[ ! -f /etc/yum.repos.d/google-chrome.repo ]] && { err "repos: Chrome repo missing"; status=1; }
            is_repo_enabled vscode && [[ ! -f /etc/yum.repos.d/vscode.repo ]] && { err "repos: VS Code repo missing"; status=1; }
            is_repo_enabled brave && [[ ! -f /etc/yum.repos.d/brave-browser.repo ]] && { err "repos: Brave repo missing"; status=1; }
            is_repo_enabled librewolf && [[ ! -f /etc/yum.repos.d/librewolf.repo ]] && { err "repos: Librewolf repo missing"; status=1; }
            ;;
        media)
            rpm -q ffmpeg libva libva-utils &>/dev/null || { err "media: base codecs missing"; status=1; }
            rpm -q openh264 gstreamer1-plugin-openh264 mozilla-openh264 &>/dev/null || { err "media: OpenH264 missing"; status=1; }
            dnf repoinfo fedora-cisco-openh264 2>/dev/null | grep -q "Status.*enabled" || { err "media: openh264 repo not enabled"; status=1; }
            ;;
        drivers)
            rpm -q mesa-vulkan-drivers vulkan-loader mesa-libGLU libva-utils &>/dev/null || { err "drivers: Mesa base missing"; status=1; }
            for vendor in "${GPU_VENDORS[@]}"; do
                case $vendor in
                    amd) rpm -q mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld &>/dev/null || { err "drivers: AMD drivers missing"; status=1; } ;;
                    intel) is_true "$INTEL_LEGACY" && rpm -q libva-intel-driver &>/dev/null || rpm -q libva-intel-media-driver &>/dev/null || { err "drivers: Intel driver missing"; status=1; } ;;
                esac
            done
            ;;
        apps)
            for list in "${RPM_LISTS[@]}"; do
                local file="$ROOT/packages/rpm/$list.txt"
                [[ -f $file ]] || { err "apps: list $list not found"; status=1; continue; }
                while read -r pkg; do
                    [[ -z $pkg || $pkg == \#* || $pkg == @* ]] && continue
                    rpm -q "$pkg" &>/dev/null || { err "apps: $pkg (RPM) not installed"; status=1; }
                done < <(read_list "$file")
            done
            for list in "${FLATPAK_LISTS[@]}"; do
                local file="$ROOT/packages/flatpak/$list.txt"
                [[ -f $file ]] || { err "apps: list $list not found"; status=1; continue; }
                while read -r app; do
                    [[ -z $app || $app == \#* ]] && continue
                    if ! flatpak info "$app" &>/dev/null; then
                        err "apps: $app (Flatpak) not installed"
                        status=1
                    fi
                done < <(read_list "$file")
            done
            ;;
        fonts)
            [[ -f "$HOME/.local/share/fonts/google-sans-flex/GoogleSansFlex.ttf" ]] || { err "fonts: Google Sans Flex not installed"; status=1; }
            if is_true "$SET_DEFAULT_FONT"; then
                gsettings get org.gnome.desktop.interface font-name 2>/dev/null | grep -q "Google Sans Flex" || { err "fonts: default font not applied"; status=1; }
            fi
            ;;
        cleanup)
            :
            ;;
    esac
    return $status
}

verify_all() {
    local m has_failed=0
    step "Verifying installation..."
    for m in "${MODULES[@]}"; do
        info "Checking: $m"
        verify_module "$m" || { FAILED+=("$m"); has_failed=1; }
    done
    if (( has_failed )); then
        err "Failures found: ${FAILED[*]}"
        return 1
    fi
    info "All checks passed"
    return 0
}

summarize() {
    step "Summary"
    [[ -e $STATE_DIR/reboot ]] && info "Reboot recommended"
    if (( ${#FAILED[@]} )); then
        err "Modules with errors: ${FAILED[*]}"
        exit 1
    fi
    info "Done"
}

main() {
    parse_args "$@"
    validate_modules
    load_config
    check_environment
    select_modules

    if [[ $VERIFY_ONLY == true ]]; then
        verify_all
        exit $?
    fi

    step "fedora-setup — Fedora Workstation Post-Install"
    info "Selected modules: ${SELECTED[*]}"
    echo

    if [[ $INTERACTIVE == true && $AUTO_YES == false ]]; then
        confirm "Continue?" || die "Cancelled by user"
    fi

    STATE_DIR=$(mktemp -d)
    trap cleanup_state EXIT
    is_true "$DRY_RUN" || start_sudo_keepalive

    for m in "${SELECTED[@]}"; do
        set +e
        run_module "$m"
        local status=$?
        set -e
        (( status != 0 )) && FAILED+=("$m")
    done
    summarize
}

main "$@"
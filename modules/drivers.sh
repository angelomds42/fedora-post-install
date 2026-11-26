drivers::run() {
    local vendor
    local -a vendors=("${GPU_VENDORS[@]}")

    if (( ${#vendors[@]} == 0 )); then
        mapfile -t vendors < <(drivers::detect)
    fi
    if (( ${#vendors[@]} == 0 )); then
        info "no supported GPU detected"
        return 0
    fi

    for vendor in "${vendors[@]}"; do
        case $vendor in
            amd|intel) ;;
            *) err "unsupported GPU: $vendor (supported: amd, intel)"; return 1 ;;
        esac
        info "gpu: $vendor"
        "drivers::$vendor"
    done
}

drivers::detect() {
    local gpus
    gpus=$(lspci 2>/dev/null | grep -Ei 'vga|3d controller|display controller' || true)
    grep -Eqiw 'amd|ati' <<<"$gpus" && echo amd
    grep -qi intel <<<"$gpus" && echo intel
}

drivers::mesa() {
    run sudo dnf install -y mesa-vulkan-drivers vulkan-loader mesa-libGLU libva-utils
}

drivers::amd() {
    drivers::mesa
    run sudo dnf install -y --allowerasing mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
}

drivers::intel() {
    drivers::mesa
    if is_true "$INTEL_LEGACY"; then
        run sudo dnf install -y libva-intel-driver
    else
        run sudo dnf install -y libva-intel-media-driver
    fi
}
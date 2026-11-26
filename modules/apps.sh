apps::run() {
    local status=0
    apps::install_lists rpm dnf_install "${RPM_LISTS[@]}" || status=1
    apps::install_lists flatpak flatpak_install "${FLATPAK_LISTS[@]}" || status=1
    return "$status"
}

apps::install_lists() {
    local kind=$1 installer=$2 name file
    local -a items
    local status=0
    shift 2

    for name in "$@"; do
        file="$ROOT/packages/$kind/$name.txt"
        [[ -f $file ]] || { err "list not found: $file"; status=1; continue; }
        info "$kind: $name"
        mapfile -t items < <(read_list "$file")
        "$installer" "${items[@]}" || status=1
    done
    return "$status"
}
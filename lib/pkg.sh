read_list() {
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

report_failures() {
    local -a failed=("$@")
    (( ${#failed[@]} == 0 )) && return 0
    err "failed: ${failed[*]}"
    return 1
}

dnf_install() {
    (( $# )) || return 0
    if run sudo dnf install -y "$@"; then
        return 0
    fi
    warn "transaction failed, trying packages individually"
    local pkg
    local -a failed=()
    for pkg in "$@"; do
        run sudo dnf install -y "$pkg" || failed+=("$pkg")
    done
    report_failures "${failed[@]}"
}

flatpak_install() {
    local id
    local -a failed=()
    for id in "$@"; do
        flatpak info "$id" &>/dev/null && continue
        run sudo flatpak install -y --noninteractive flathub "$id" || failed+=("$id")
    done
    report_failures "${failed[@]}"
}

deploy() {
    local rel=$1
    local src="$ROOT/files/$rel"
    [[ -f $src ]] || die "source file not found: $src"
    case $rel in
        home/*) run install -Dm644 "$src" "$HOME/${rel#home/}" ;;
        *)      run sudo install -Dm644 "$src" "/$rel" ;;
    esac
}

add_repo_from_url() {
    local name=$1 url=$2
    local dest=/etc/yum.repos.d/$name.repo
    [[ -f $dest ]] && return 0
    run sudo curl -fsSL -o "$dest" "$url"
}
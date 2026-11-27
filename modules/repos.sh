repos::run() {
    local repo
    for repo in "${REPOS[@]}"; do
        local fn="repos::$repo"
        [[ $(type -t "$fn") == function ]] || { err "unknown repo: $repo"; return 1; }
        info "repo: $repo"
        "$fn"
    done
}

repos::rpmfusion() {
    local ver
    ver=$(rpm -E %fedora)
    rpm -q rpmfusion-free-release rpmfusion-nonfree-release &>/dev/null || run sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm"
    run sudo dnf install -y rpmfusion-free-appstream-data rpmfusion-nonfree-appstream-data
}

repos::flathub() {
    if flatpak remote-list | grep -q '^fedora'; then
        run sudo flatpak remote-delete fedora
    else
        info "fedora flatpak remote not present"
    fi
    run sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

repos::chrome() { deploy etc/yum.repos.d/google-chrome.repo; }

repos::vscode() {
    run sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    deploy etc/yum.repos.d/vscode.repo
}

repos::brave() {
    local base=https://brave-browser-rpm-release.s3.brave.com
    add_repo_from_url brave-browser "$base/brave-browser.repo"
    run sudo rpm --import "$base/brave-core.asc"
}

repos::librewolf() { add_repo_from_url librewolf https://repo.librewolf.net/librewolf.repo; }
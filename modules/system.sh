system::run() {
    deploy etc/dnf/libdnf5.conf.d/99-fedora-setup.conf
    run sudo dnf upgrade -y --refresh
    run sudo dnf install -y dnf5-plugins pciutils

    if is_true "$UPDATE_FIRMWARE"; then
        run sudo fwupdmgr refresh --force || warn "firmware metadata refresh failed"
        run sudo fwupdmgr update -y --no-reboot-check || [[ $? -eq 2 ]] || warn "firmware update failed"
    fi
    request_reboot
}
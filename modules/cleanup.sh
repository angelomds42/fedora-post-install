cleanup::run() {
    run sudo dnf autoremove -y
    run sudo dnf clean all
}
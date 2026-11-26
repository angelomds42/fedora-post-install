media::run() {
    run sudo dnf group install -y multimedia
    run sudo dnf install -y --allowerasing ffmpeg
    run sudo dnf upgrade -y @multimedia --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin
    run sudo dnf group install -y sound-and-video
    run sudo dnf install -y libva libva-utils

    run sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1
    run sudo dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264
}
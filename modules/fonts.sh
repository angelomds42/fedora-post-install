readonly FONT_FAMILY="Google Sans Flex"
readonly FONT_URL="https://github.com/google/fonts/raw/main/ofl/googlesansflex/GoogleSansFlex%5BROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf"
readonly FONT_DIR="$HOME/.local/share/fonts/google-sans-flex"

fonts::run() {
    fonts::install
    is_true "$SET_DEFAULT_FONT" && fonts::set_default
}

fonts::install() {
    local file=$FONT_DIR/GoogleSansFlex.ttf
    [[ -f $file ]] && return 0
    run mkdir -p "$FONT_DIR"
    run curl -fsSL -o "$file" "$FONT_URL"
    run fc-cache -f "$FONT_DIR"
}

fonts::set_default() {
    gsettings get org.gnome.desktop.interface font-name &>/dev/null || { warn "GNOME settings indisponível"; return 0; }
    run gsettings set org.gnome.desktop.interface font-name "$FONT_FAMILY $FONT_SIZE"
    run gsettings set org.gnome.desktop.interface document-font-name "$FONT_FAMILY $FONT_SIZE"
    run gsettings set org.gnome.desktop.wm.preferences titlebar-font "$FONT_FAMILY Bold $FONT_SIZE"
    deploy home/.config/fontconfig/fonts.conf
    run fc-cache -f
}
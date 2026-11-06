#!/bin/bash
set -euo pipefail

link() {
    local target="$HOME/.config/$1"
    # ln would put the link inside a real folder, so move any real one out of the way first.
    if [[ -e "$target" && ! -L "$target" ]]; then
        local backup="$target.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$target" "$backup"
        echo "Moved existing $target to $backup"
    fi
    ln -sfn "$HOME/dotfiles/.config/$1" "$target"
}

echo "Installing dotfiles..."

mkdir -p "$HOME/.config"
for config in niri hypr framework waybar alacritty quickshell fuzzel wlogout systemd xdg-desktop-portal; do
    link "$config"
done

xdg-mime default pcmanfm-qt.desktop inode/directory
# Apps started outside a terminal only go dark if they get this preference.
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

echo "Done."

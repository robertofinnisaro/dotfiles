#!/bin/bash

echo "Installing dotfiles..."

ln -sf ~/dotfiles/.config/hypr ~/.config/hypr
ln -sf ~/dotfiles/.config/waybar ~/.config/waybar
ln -sf ~/dotfiles/.config/alacritty ~/.config/alacritty
ln -sf ~/dotfiles/.config/quickshell ~/.config/quickshell
ln -sf ~/dotfiles/.config/fuzzel ~/.config/fuzzel

echo "Done."

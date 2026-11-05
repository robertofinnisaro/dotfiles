# Orthanc dotfiles

An Arch Linux desktop themed on *The Lord of the Rings*, built for a Framework Laptop 12. It runs the [niri](https://github.com/YaLTeR/niri) scrolling compositor with a custom [Quickshell](https://quickshell.org) shell, the Palantír.

## Branches

| Branch | Desktop |
|---|---|
| `niri` | niri, with Hyprland kept working as a fallback while the move settles |
| `main` | The original Hyprland setup |

This README describes the `niri` branch. Both compositors can be chosen at the login screen.

## Setup

| | |
|---|---|
| OS | Arch Linux |
| Compositor | niri (fallback: Hyprland) |
| Shell and panels | Quickshell |
| Bar | Waybar, with a compact layout in portrait |
| Lock and idle | hyprlock and swayidle |
| Night light | wlsunset |
| Terminal | Alacritty |

## Keybinds

**Press `Super + /` to open the Red Book of Westmarch**, which lists every keybind. It reads the niri config each time it opens, so it can't go out of date.

The ones to know first:

| Keys | Action |
|---|---|
| `Super + Space` | Search and launch apps |
| `Super + D` | The Palantír |
| `Super + G` | The Field Atlas |
| `Super + A` | The Map of Middle-earth |
| `Super + W` | The Seeing Stone |
| `Super + K` | On-screen keyboard |
| `Super + 1–5` | Switch workspace |
| `Super + Shift + 1–5` | Send window to a workspace |
| `Super + Tab` | Overview of all workspaces |
| `Super + H` | Hide or show all windows |
| `Super + F` | Maximize, keeping gaps |
| `Super + R` | Cycle column width |
| `Super + Shift + T` | Switch tablet or laptop mode |

To add a bind, edit `.config/niri/config.kdl`. Give it a `hotkey-overlay-title` and it appears in the Red Book, under the comment above it.

## Workspaces

Apps open on their own workspace and take the view with them. Unassigned apps open where you are.

| Keys | Workspace | Purpose | Apps |
|---|---|---|---|
| `Super + 1` | Rivendell | Dev | Claude, VSCodium, MATLAB |
| `Super + 2` | Bree | Browser | Brave |
| `Super + 3` | Mordor | Gaming | Steam and its games, Prism Launcher, Minecraft, Parsec |
| `Super + 4` | Gondor | Notes | Obsidian |
| `Super + 5` | The Shire | General | None |

The rules are in `.config/niri/config.kdl`. To find an app's ID, run `niri msg windows` while it's open.

## Realms

Realms are performance modes, chosen in the Palantír's Realms tab. They last until you log out.

| Realm | Effects |
|---|---|
| The Shire, Mordor | Off: animations, blur, shadows and window transparency |
| Rivendell, The Palantír | On |

They share some names with the workspaces, but switching workspace doesn't change realm.

## Framework Laptop 12

Folding into tablet mode rotates the screen to match the accelerometer, and touch and stylus input follow it. Waybar swaps to its compact layout in portrait.

Rotation has three modes: `auto`, `tablet` and `laptop`. Manual `tablet` or `laptop` mode ignores the hinge until you change it, and `Super + Shift + T` switches between those two. To go back to following the hinge:

```bash
python3 ~/.config/framework/palantir-framework12.py mode auto
```

To check the rotation controller and sensors:

```bash
python3 ~/.config/framework/palantir-framework12.py doctor
```

## Installation

The scripts expect the repo at `~/dotfiles`.

```bash
git clone -b niri https://github.com/robertofinnisaro/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` symlinks each folder into `~/.config`. A real folder already at that path is renamed with a `.bak` suffix, not deleted.

Install the packages:

```bash
sudo pacman -S niri xwayland-satellite quickshell waybar swaybg swayidle hyprlock wlsunset fuzzel alacritty grim slurp wl-clipboard cliphist brightnessctl playerctl jq iio-sensor-proxy libinput-tools ydotool xdg-desktop-portal-gnome xdg-desktop-portal-gtk gnome-keyring network-manager-applet blueman pcmanfm-qt qt6ct
```

You'll also need:

- **`wlogout`**, from the AUR, for the power menu.
- **Fonts:** Cinzel, Material Symbols and Noto Sans.
- **Wallpaper:** `~/Pictures/Wallpapers/wallpaper-orthanc.jpg`, which isn't in this repo.

Then choose **niri** at the login screen.

The config has two values tied to this machine, because niri doesn't expand variables. Change them in `.config/niri/config.kdl` for a different user:

- The username in the wallpaper path.
- The uid `1000` in the `/run/user/1000` paths.

## Layout

```text
.config/
├── niri/              Compositor config and helper scripts
├── quickshell/        The Palantír shell
│   ├── modules/lotr/  Panels: Palantír, Field Atlas, Map, Seeing Stone, Red Book, search
│   ├── services/      Compositor.qml is the shell's link to niri or Hyprland
│   └── scripts/       Keybind actions, realms, keybind list, logout
├── waybar/            config (Hyprland), config-niri, config-niri-portrait
├── framework/         Framework 12 rotation and tablet-mode controller
├── hypr/              Hyprland config, hyprlock, and scripts both compositors share
├── systemd/user/      Services for the shell and clipboard history
├── wlogout/           Power menu
├── alacritty/
└── fuzzel/
```

`.config/hypr/scripts/` still holds the session startup that niri uses, so don't delete that folder without moving it first.

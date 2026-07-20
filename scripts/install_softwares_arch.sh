#!/usr/bin/env bash
# Post-install setup script for Arch-based systems (made for Omarchy).
# Installs the software I use and applies base configuration.
#
# Omarchy already ships Hyprland, hyprlock, hypridle and the portal stack,
# so this script only covers what it does NOT provide.
#
# Usage:
#   ./install_softwares_arch.sh       # full run (system upgrade + install + config)
#   ./install_softwares_arch.sh -s    # skip the full system upgrade (pacman -Syu)
#
# Docker, Node, nvm etc. are intentionally NOT here: install those on demand
# so you always get the latest version.
#
# Author: Henry

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run this script as your normal user, not as root (makepkg refuses to run as root)." >&2
  exit 1
fi

SKIP_UPGRADE=false
[[ "${1:-}" == "-s" ]] && SKIP_UPGRADE=true

# Everything from the official repos goes here. `pacman -S --needed` skips
# packages that are already installed, so adding a program is just adding a
# word to this list.
PACMAN_PACKAGES=(
  # build tools (C, make & friends — base-devel brings gcc, make, pkgconf...)
  base-devel cmake clang go perl

  # CLI tools
  git curl wget unzip tar stow ripgrep fzf bat jq socat fastfetch btop zsh
  python python-pip neovim

  # Wayland utilities / Brain_Shell dependencies
  wl-clipboard cliphist grim slurp swww wf-recorder brightnessctl playerctl
  pamixer libpulse libnotify imagemagick cava mpd mpc
  easyeffects # music/equalizer.sh loads presets through it
  networkmanager # Brain_Shell relies on nmcli; only enable the service if Omarchy isn't already managing the network

  # qylock lockscreen themes (QML modules not pulled in by quickshell itself)
  qt6-5compat qt6-multimedia qt6-svg

  # desktop apps
  firefox kitty mpv thunar gparted pavucontrol qalculate-gtk loupe nvtop
  obs-studio kdenlive
  rofi # goanime, powermenu and clipboard-delete binds still go through rofi scripts

  # system / hardware
  ntfs-3g exfatprogs bluez bluez-utils blueman
  alsa-utils # amixer, used by the battery popup suspend action
)

# AUR packages, installed with yay. No Nix needed on Arch: the repos already
# ship a recent Qt, so Quickshell installs natively (unlike on Ubuntu 24.04).
AUR_PACKAGES=(
  quickshell  # Brain_Shell runtime (pulls the Qt6 stack as dependencies)
  matugen-bin # dynamic colors from the wallpaper (MatugenColors.qml)
  visual-studio-code-bin # VS Code via AUR
)

on_error() {
  local code=$?
  echo -e "\n\033[1;31m[ERROR]\033[0m \033[33mExecution failed (exit code: $code)\033[0m" >&2
}
trap 'on_error' ERR

pretty_log() {
  local TYPE=$1
  local LOG_NAME=$2
  local MESSAGE=$3
  local STATUS="${4:-info}"
  local TAG=""

  case "$TYPE" in
    "-s") TAG="SOFTWARE  " ;;
    "-p") TAG="PACKAGE   " ;;
    "-c") TAG="CONFIG    " ;;
    "-e") TAG="ERROR     "; STATUS="error" ;;
    *) TAG="$TYPE" ;;
  esac

  case "$STATUS" in
    success)
      echo -e "\n\033[1;36m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t     \033[3;32m$MESSAGE ✓\033[0m"
      ;;
    info)
      echo -e "\n\033[1;36m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t     \033[33m$MESSAGE...\033[0m\n"
      ;;
    error)
      echo -e "\n\033[1;31m$TAG\033[0m  \033[1m$LOG_NAME\033[0m\n\t     \033[33m$MESSAGE\033[0m" >&2
      ;;
  esac
}

ensure_yay() {
  local LOG="[yay-check]"

  if command -v yay &> /dev/null; then
    pretty_log -p "$LOG" "Already installed" success
    return 0
  fi

  # Omarchy ships yay, so this is just a safety net for vanilla Arch installs.
  pretty_log -p "$LOG" "Bootstrapping yay from the AUR" info
  local BUILD_DIR
  BUILD_DIR=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$BUILD_DIR/yay-bin"
  (cd "$BUILD_DIR/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$BUILD_DIR"

  pretty_log -p "$LOG" "Installed successfully" success
}

install_pacman_packages() {
  local LOG="[pacman-install]"

  pretty_log -p "$LOG" "Installing official repo packages (already installed ones are skipped)" info
  sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"

  pretty_log -p "$LOG" "All official packages are in place" success
}

install_aur_packages() {
  local LOG="[aur-install]"

  pretty_log -p "$LOG" "Installing AUR packages (quickshell compiles, this can take a few minutes)" info
  yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"

  pretty_log -p "$LOG" "All AUR packages are in place" success
}

configure_default_shell() {
  local LOG="[zsh-config]"
  local ZSH_PATH
  ZSH_PATH=$(command -v zsh)

  if [[ "$(getent passwd "$USER" | cut -d: -f7)" == "$ZSH_PATH" ]]; then
    pretty_log -c "$LOG" "zsh is already the default shell" success
    return 0
  fi

  pretty_log -c "$LOG" "Setting zsh as the default shell" info
  chsh -s "$ZSH_PATH"

  pretty_log -c "$LOG" "Done. Log out and back in to apply" success
}

install_ohmyzsh() {
  local LOG="[Oh-My-Zsh]"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    pretty_log -s "$LOG" "Already installed" success
    return 0
  fi

  pretty_log -s "$LOG" "Installing Oh My Zsh" info
  # --unattended + env vars: don't switch shells mid-script and don't touch
  # an existing .zshrc (mine comes from the dotfiles via stow).
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

  pretty_log -s "$LOG" "Installed successfully" success
}

install_ohmyposh() {
  local LOG="[Oh-My-Posh]"

  export PATH="$PATH:$HOME/.local/bin"

  if command -v oh-my-posh &> /dev/null; then
    pretty_log -s "$LOG" "Already installed" success
  else
    pretty_log -s "$LOG" "Installing Oh My Posh" info
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
    pretty_log -s "$LOG" "Installed. Open a new terminal to load the profile" success
  fi

  # The patched family is named "Hasklug", the upstream font "Hasklig".
  if fc-list | grep -qiE "hasklig|hasklug"; then
    pretty_log -s "[Hasklug-font]" "Nerd Font already installed" success
    return 0
  fi

  pretty_log -s "[Hasklug-font]" "Installing the Hasklug Nerd Font" info
  oh-my-posh font install Hasklig

  pretty_log -s "[Hasklug-font]" "Installed successfully" success
}

# Roots where Firefox may keep profiles: ~/.mozilla is the classic location,
# but newer builds use XDG (~/.config/mozilla) when ~/.mozilla doesn't exist.
FIREFOX_ROOTS=("$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox")

# Prints the default Firefox profile directory, or fails if none exists.
firefox_profile_dir() {
  local ROOT INI PROFILE_PATH

  for ROOT in "${FIREFOX_ROOTS[@]}"; do
    INI="$ROOT/profiles.ini"
    [[ -f "$INI" ]] || continue

    # Modern Firefox: the [Install*] section points at the default profile.
    PROFILE_PATH=$(awk -F= '/^\[Install/{found=1; next} /^\[/{found=0} found && /^Default=/{print $2; exit}' "$INI")
    # Fallbacks: the profile marked Default=1, then the first profile listed.
    [[ -n "$PROFILE_PATH" ]] || PROFILE_PATH=$(awk -F= '/^Path=/{path=$2} /^Default=1$/{print path; exit}' "$INI")
    [[ -n "$PROFILE_PATH" ]] || PROFILE_PATH=$(awk -F= '/^Path=/{print $2; exit}' "$INI")
    [[ -z "$PROFILE_PATH" ]] && continue

    if [[ "$PROFILE_PATH" == /* ]]; then
      echo "$PROFILE_PATH"
    else
      echo "$ROOT/$PROFILE_PATH"
    fi
    return 0
  done

  # Last resort: any profile-looking directory under either root.
  find "${FIREFOX_ROOTS[@]}" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -n 1 | grep .
}

configure_firefox() {
  local LOG="[Firefox-config]"

  if ! command -v firefox &> /dev/null; then
    pretty_log -e "$LOG" "Firefox is not installed, skipping its configuration"
    return 0
  fi

  # The old Ubuntu script kept breaking here: it tried to configure a profile
  # that didn't exist yet (Firefox only creates one on first launch). A short
  # headless run creates the default profile deterministically.
  if [[ ! -f "${FIREFOX_ROOTS[0]}/profiles.ini" && ! -f "${FIREFOX_ROOTS[1]}/profiles.ini" ]]; then
    pretty_log -c "$LOG" "Creating the default profile (short headless run)" info
    timeout 15 firefox --headless > /dev/null 2>&1 || true
  fi

  local PROFILE_DIR
  if ! PROFILE_DIR=$(firefox_profile_dir); then
    # Soft failure on purpose: everything else is already installed, so don't
    # abort the whole run over the browser config.
    pretty_log -e "$LOG" "No profile found under ~/.mozilla/firefox or ~/.config/mozilla/firefox. Open Firefox once and re-run the script"
    return 0
  fi

  mkdir -p "$PROFILE_DIR/chrome"

  cat > "$PROFILE_DIR/user.js" << 'EOF'
/* Customization via CSS (userChrome/userContent) */
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

/* Enable dark theme */
user_pref("ui.systemUsesDarkTheme", 1);

/* Fonts */
user_pref("font.name.sans-serif.x-western", "Hasklug Nerd Font Propo");
user_pref("font.name.monospace.x-western", "Hasklug Nerd Font Propo");
user_pref("font.minimum-size.th", 13);
user_pref("font.size.variable.x-western", 13);
user_pref("font.size.fixed.x-western", 13);
user_pref("browser.display.use_document_fonts", 1);

/* General preferences */
user_pref("browser.download.useDownloadDir", false);
user_pref("browser.download.deletePrivate", true);
user_pref("browser.download.deletePrivate.chosen", true);
user_pref("browser.tabs.groups.smart.userEnabled", false);
user_pref("browser.tabs.hoverPreview.showThumbnails", false);
user_pref("accessibility.typeaheadfind", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.ctrlTab.sortByRecentlyUsed", true);
user_pref("general.autoScroll", true);
user_pref("general.smoothScroll", true);
user_pref("signon.rememberSignons", false);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("privacy.globalprivacycontrol.was_ever_enabled", true);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

/* Restore previous session tabs */
user_pref("browser.startup.page", 3);

/* Disable recommendations */
user_pref("browser.newtabpage.activity-stream.feeds.recommendationprovider", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.suggest.searches", false);
EOF

  pretty_log -c "$LOG" "user.js written to $PROFILE_DIR" success
}

echo -e "\n\033[1;33m[info] --- starting software installation ---\033[0m\n"

# Prime sudo once so later steps don't stall waiting for a password.
sudo -v

if ! $SKIP_UPGRADE; then
  echo -e "\033[1;33m[pacman -Syu] full system upgrade\033[0m"
  sudo pacman -Syu
fi

ensure_yay

install_pacman_packages

install_aur_packages

configure_default_shell

install_ohmyzsh

install_ohmyposh

configure_firefox

echo -e "\n\033[1;33m[info] --- done. Open a new terminal (or re-login) to load zsh, oh-my-posh and PATH changes ---\033[0m\n"

exit 0

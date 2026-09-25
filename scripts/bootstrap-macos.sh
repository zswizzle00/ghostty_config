#!/usr/bin/env bash
#
# bootstrap-macos.sh - terminal setup for macOS.
#
# Usage:
#   ./bootstrap-macos.sh                 core + extra CLI tools
#   ./bootstrap-macos.sh --minimal       core CLI tools only
#   ./bootstrap-macos.sh --with-gui      also install GUI apps
#   ./bootstrap-macos.sh --all-fonts     install more Nerd Fonts
#   ./bootstrap-macos.sh --no-nvchad     skip Neovim/NvChad
#   ./bootstrap-macos.sh --configs-only  only rewrite the config files
#

set -uo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
parse_args "$@"

[[ "$(uname -s)" == Darwin ]] || die "macOS only. Use bootstrap-debian.sh on Linux."
[[ $EUID -ne 0 ]] || die "don't run as root, it writes to \$HOME."

step "macOS $(sw_vers -productVersion 2>/dev/null || echo '') on $(uname -m)"

ensure_brew() {
  if have brew; then
    skip "Homebrew already installed"
    return 0
  fi
  step "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew install failed"
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  [[ -x /usr/local/bin/brew ]]   && eval "$(/usr/local/bin/brew shellenv)"
}

brew_formula() {
  local p
  for p in "$@"; do
    if brew list --formula "$p" >/dev/null 2>&1; then
      skip "$p already installed"
    elif brew install "$p"; then
      info "installed $p"
    else
      FAILED_PKGS+=("$p")
    fi
  done
}

brew_cask() {
  local c
  for c in "$@"; do
    if brew list --cask "$c" >/dev/null 2>&1; then
      skip "$c already installed"
    elif brew install --cask "$c"; then
      info "installed $c"
    else
      FAILED_PKGS+=("$c")
    fi
  done
}

install_core() {
  step "Installing core CLI tools"
  brew_formula ripgrep fzf jq tree eza zoxide tealdeer uv fd bat \
               htop btop fastfetch cowsay lolcat neovim git tree-sitter
}

install_extras() {
  [[ $DO_EXTRAS -eq 1 ]] || { skip "extra CLI tools (--minimal)"; return 0; }
  step "Installing extra CLI tools"
  brew_formula gh gitleaks lsd glow fortune magic-wormhole opentofu scrcpy

  if have bun || [[ -x "$HOME/.bun/bin/bun" ]]; then
    skip "bun already installed"
  else
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 \
      && info "installed bun" || FAILED_PKGS+=("bun")
  fi

  if have ty; then
    skip "ty already installed"
  elif have uv; then
    uv tool install ty >/dev/null 2>&1 && info "installed ty" || FAILED_PKGS+=("ty")
  else
    FAILED_PKGS+=("ty (needs uv)")
  fi
}

install_gui() {
  [[ $DO_GUI -eq 1 ]] || { skip "GUI apps (pass --with-gui)"; return 0; }
  step "Installing GUI apps"
  brew_cask ghostty vlc powershell shottr sublime-text sublime-merge \
            google-cloud-sdk alfred utm
  NOTES+=("Some casks ask for an admin password to write to /Applications.")
}

install_fonts() {
  step "Installing MesloLGS Nerd Font"
  # Font casks live in homebrew/cask now, the old cask-fonts tap is gone.
  brew_cask font-meslo-lg-nerd-font

  [[ $DO_ALL_FONTS -eq 1 ]] || return 0
  step "Installing additional Nerd Fonts"
  brew_cask font-fira-code-nerd-font font-jetbrains-mono-nerd-font \
            font-hack-nerd-font font-caskaydia-cove-nerd-font \
            font-sauce-code-pro-nerd-font font-ubuntu-mono-nerd-font \
            font-iosevka-nerd-font
  NOTES+=("Every Nerd Font: brew search '/font-.*-nerd-font/' | xargs -I{} brew install --cask {}")
}

setup_tealdeer() {
  have tldr || return 0
  step "Setting up tldr"
  if ! tealdeer_is_current; then
    warn "tealdeer $(tealdeer_version) needs 1.8.0+"
    brew upgrade tealdeer >/dev/null 2>&1
    tealdeer_is_current && info "upgraded to $(tealdeer_version)" \
                        || warn "still $(tealdeer_version), try: brew update && brew upgrade tealdeer"
  else
    skip "tealdeer $(tealdeer_version) is current"
  fi

  if tldr --update >/dev/null 2>&1; then
    info "page cache updated"
  else
    warn "tldr --update failed"
    NOTES+=("tldr cache is empty. See https://github.com/tealdeer-rs/tealdeer/issues/459")
  fi
}

# A config in Application Support overrides the XDG one.
move_stray_ghostty_configs() {
  local appsup="$HOME/Library/Application Support/com.mitchellh.ghostty"
  local stray
  for stray in "$appsup/config" "$appsup/config.ghostty"; do
    if [[ -f "$stray" ]]; then
      backup "$stray"
      NOTES+=("Moved aside $(basename "$stray") in Application Support, it would have overridden the XDG config.")
    fi
  done
}

main() {
  if [[ $CONFIGS_ONLY -eq 0 ]]; then
    ensure_brew
    install_core
    install_extras
    install_gui
    install_fonts
    install_omz
    install_zsh_plugins
    install_nvchad
  else
    step "Configs only, skipping installs"
  fi
  write_zshrc
  write_ghostty_config macos
  move_stray_ghostty_configs
  post_install
  summary
}

main

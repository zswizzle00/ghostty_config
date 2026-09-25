#!/usr/bin/env bash
#
# bootstrap-debian.sh - terminal setup for Debian and Ubuntu.
#
# Usage:
#   ./bootstrap-debian.sh                 core + extra CLI tools
#   ./bootstrap-debian.sh --minimal       core CLI tools only
#   ./bootstrap-debian.sh --with-gui      also install GUI apps
#   ./bootstrap-debian.sh --all-fonts     install more Nerd Fonts
#   ./bootstrap-debian.sh --no-nvchad     skip Neovim/NvChad
#   ./bootstrap-debian.sh --configs-only  only rewrite the config files
#

set -uo pipefail

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
parse_args "$@"
FAILED_HINT="Usually means the package is missing from this release."

[[ "$(uname -s)" == Linux ]] || die "Linux only. Use bootstrap-macos.sh on a Mac."
[[ -f /etc/debian_version ]] || die "not Debian or Ubuntu. Install packages yourself, then run with --configs-only."
[[ $EUID -ne 0 ]] || die "don't run as root, it writes to \$HOME."
have sudo || die "sudo is required."

step "Detected $( (. /etc/os-release && echo "$PRETTY_NAME") 2>/dev/null || cat /etc/debian_version) on $(uname -m)"

# One at a time so a package missing from this release doesn't abort the run.
apt_install() {
  local p
  for p in "$@"; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      skip "$p already installed"
    elif sudo apt-get install -y -qq "$p" >/dev/null 2>&1; then
      info "installed $p"
    else
      FAILED_PKGS+=("$p")
    fi
  done
}

# For tools with no apt package. Asset name comes from the API, not hardcoded.
install_from_github_release() {
  local repo="$1" bin="$2" extra="${3:-}" arch url tmp found
  case "$(uname -m)" in
    x86_64|amd64)  arch='x86_64|amd64' ;;
    aarch64|arm64) arch='aarch64|arm64' ;;
    *) return 1 ;;
  esac

  url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
          | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 \
          | grep -iE 'linux' | grep -iE "$arch" \
          | grep -viE '\.(sha256|asc|sig|deb|rpm|msi)$' \
          | grep -iE "${extra:-.}" | head -1)"
  [[ -n "$url" ]] || return 1

  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/dl" "$url"; then
    case "$url" in
      *.tar.gz|*.tgz) tar -xzf "$tmp/dl" -C "$tmp" 2>/dev/null ;;
      *.zip)          unzip -q -o "$tmp/dl" -d "$tmp" 2>/dev/null ;;
      *)              mv "$tmp/dl" "$tmp/$bin" ;;
    esac
    found="$(find "$tmp" -type f -name "$bin" -perm -u+x 2>/dev/null | head -1)"
    [[ -z "$found" ]] && found="$(find "$tmp" -type f -name "$bin" 2>/dev/null | head -1)"
    if [[ -n "$found" ]]; then
      mkdir -p "$HOME/.local/bin"
      install -m 0755 "$found" "$HOME/.local/bin/$bin"
      rm -rf "$tmp"; hash -r 2>/dev/null
      return 0
    fi
  fi
  rm -rf "$tmp"
  return 1
}

install_core() {
  step "Installing core CLI tools"
  sudo apt-get update -qq || die "apt-get update failed"

  apt_install zsh git curl unzip fontconfig ca-certificates \
              ripgrep fzf jq tree htop btop cowsay neovim fd-find bat
  # Only in Debian 13+ / Ubuntu 24.04+.
  apt_install eza zoxide tealdeer fastfetch lolcat

  if have uv; then
    skip "uv already installed"
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 \
      && info "installed uv" || FAILED_PKGS+=("uv")
  fi

  NOTES+=("Debian names fd as 'fdfind' and bat as 'batcat'. Both are aliased in .zshrc.")
}

install_extras() {
  [[ $DO_EXTRAS -eq 1 ]] || { skip "extra CLI tools (--minimal)"; return 0; }
  step "Installing extra CLI tools"

  apt_install gh lsd magic-wormhole scrcpy fortune-mod

  if have gitleaks; then skip "gitleaks already installed"
  elif install_from_github_release gitleaks/gitleaks gitleaks; then info "installed gitleaks"
  else FAILED_PKGS+=("gitleaks"); fi

  if have glow; then skip "glow already installed"
  elif install_from_github_release charmbracelet/glow glow; then info "installed glow"
  else FAILED_PKGS+=("glow"); fi

  if have tofu; then
    skip "opentofu already installed"
  else
    local tofu_tmp; tofu_tmp="$(mktemp -d)"
    if curl -fsSL -o "$tofu_tmp/install.sh" https://get.opentofu.org/install-opentofu.sh \
       && chmod +x "$tofu_tmp/install.sh" \
       && "$tofu_tmp/install.sh" --install-method deb >/dev/null 2>&1; then
      info "installed opentofu"
    else
      FAILED_PKGS+=("opentofu")
    fi
    rm -rf "$tofu_tmp"
  fi

  if have bun || [[ -x "$HOME/.bun/bin/bun" ]]; then
    skip "bun already installed"
  else
    curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1 \
      && info "installed bun" || FAILED_PKGS+=("bun")
  fi

  # uv may have just been installed to ~/.local/bin, which isn't on PATH yet.
  local uv_bin; uv_bin="$(command -v uv || echo "$HOME/.local/bin/uv")"
  if have ty; then
    skip "ty already installed"
  elif [[ -x "$uv_bin" ]]; then
    "$uv_bin" tool install ty >/dev/null 2>&1
    have ty || [[ -x "$HOME/.local/bin/ty" ]] && info "installed ty" || FAILED_PKGS+=("ty")
  else
    FAILED_PKGS+=("ty (needs uv)")
  fi
}

install_gui() {
  [[ $DO_GUI -eq 1 ]] || { skip "GUI apps (pass --with-gui)"; return 0; }
  step "Installing GUI apps"
  apt_install vlc flameshot virt-manager
  NOTES+=("Shottr, Alfred and UTM are macOS only. Installed flameshot and virt-manager instead.")
  NOTES+=("Sublime Text, PowerShell and gcloud need vendor apt repos, not added here.")
  NOTES+=("Ghostty has no official Debian package. See ghostty.org for community builds.")
}

install_nerd_font() {
  local f="$1" dir="$HOME/.local/share/fonts" tmp
  if compgen -G "$dir/${f}*Nerd*" >/dev/null 2>&1; then
    skip "$f already installed"
    return 0
  fi
  mkdir -p "$dir"
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/$f.zip" \
       "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$f.zip" \
     && unzip -q -o "$tmp/$f.zip" -d "$dir"; then
    info "installed $f"
    rm -rf "$tmp"
    return 0
  fi
  rm -rf "$tmp"
  FAILED_PKGS+=("font:$f")
  return 1
}

install_fonts() {
  step "Installing MesloLGS Nerd Font"
  install_nerd_font Meslo

  if [[ $DO_ALL_FONTS -eq 1 ]]; then
    step "Installing additional Nerd Fonts"
    local f
    for f in FiraCode JetBrainsMono Hack CascadiaCode SourceCodePro UbuntuMono Iosevka; do
      install_nerd_font "$f"
    done
  fi
  fc-cache -f >/dev/null 2>&1
}

install_tealdeer_binary() {
  local arch url tmp
  case "$(uname -m)" in
    x86_64|amd64)  arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) return 1 ;;
  esac
  url="$(curl -fsSL https://api.github.com/repos/tealdeer-rs/tealdeer/releases/latest 2>/dev/null \
          | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 \
          | grep -i linux | grep -i "$arch" \
          | grep -viE '\.(sha256|asc|sig)$' | head -1)"
  [[ -n "$url" ]] || return 1

  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/tldr" "$url"; then
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/tldr" "$HOME/.local/bin/tldr"
    rm -rf "$tmp"; hash -r 2>/dev/null
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

setup_tealdeer() {
  have tldr || return 0
  step "Setting up tldr"

  if ! tealdeer_is_current; then
    warn "tealdeer $(tealdeer_version) needs 1.8.0+"
    sudo apt-get update -qq >/dev/null 2>&1
    sudo apt-get install -y -qq --only-upgrade tealdeer >/dev/null 2>&1
    if tealdeer_is_current; then
      info "upgraded to $(tealdeer_version) from apt"
    else
      info "apt still has $(tealdeer_version), fetching a release build"
      install_tealdeer_binary && info "installed tealdeer to ~/.local/bin/tldr" \
                              || warn "could not fetch a release build"
    fi
  else
    skip "tealdeer $(tealdeer_version) is current"
  fi

  local tldr_bin; tldr_bin="$(command -v tldr)"
  [[ -x "$HOME/.local/bin/tldr" ]] && tldr_bin="$HOME/.local/bin/tldr"

  if "$tldr_bin" --update >/dev/null 2>&1; then
    info "page cache updated"
  else
    warn "tldr --update failed"
    NOTES+=("tldr cache is empty. See https://github.com/tealdeer-rs/tealdeer/issues/459")
  fi
}

main() {
  if [[ $CONFIGS_ONLY -eq 0 ]]; then
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
  write_ghostty_config linux
  have ghostty || NOTES+=("Ghostty isn't installed here. The config is ready for when it is.")
  post_install
  summary
}

main

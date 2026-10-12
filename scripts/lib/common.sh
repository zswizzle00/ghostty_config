# shellcheck shell=bash
#
# Shared by bootstrap-macos.sh and bootstrap-debian.sh. Sourced, not run.
# Each script defines setup_tealdeer and its own install steps.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
FAILED_PKGS=()
FAILED_HINT=""
NOTES=()
DO_NVCHAD=1
CONFIGS_ONLY=0
DO_EXTRAS=1
DO_GUI=0
DO_ALL_FONTS=0

parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --no-nvchad)    DO_NVCHAD=0 ;;
      --configs-only) CONFIGS_ONLY=1 ;;
      --minimal)      DO_EXTRAS=0 ;;
      --with-gui)     DO_GUI=1 ;;
      --all-fonts)    DO_ALL_FONTS=1 ;;
      -h|--help)      awk 'NR>1 && /^#/{sub(/^# ?/,"");print;next} NR>1{exit}' "$0"; exit 0 ;;
      *) echo "unknown option: $arg" >&2; exit 1 ;;
    esac
  done
}

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'

step() { printf '\n%s==>%s %s%s%s\n' "$GREEN" "$RESET" "$BOLD" "$*" "$RESET"; }
info() { printf '    %s\n' "$*"; }
skip() { printf '    %sskip%s %s\n' "$DIM" "$RESET" "$*"; }
warn() { printf '    %swarn%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '\n%serror%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

backup() {
  [[ -e "$1" ]] || return 0
  mv "$1" "$1.bak.$STAMP"
  info "backed up $(basename "$1")"
}

install_omz() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    skip "oh-my-zsh already installed"
    return 0
  fi
  step "Installing oh-my-zsh"
  RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    || die "oh-my-zsh install failed"
}

clone_or_update() {
  local url="$1" dest="$2" name; name="$(basename "$dest")"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --quiet --ff-only 2>/dev/null \
      && skip "$name up to date" || warn "$name: could not update"
  else
    git clone --depth=1 --quiet "$url" "$dest" \
      && info "cloned $name" || FAILED_PKGS+=("$name")
  fi
}

install_zsh_plugins() {
  step "Installing zsh plugins and powerlevel10k"
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$custom/plugins" "$custom/themes"
  clone_or_update https://github.com/jeffreytse/zsh-vi-mode                     "$custom/plugins/zsh-vi-mode"
  clone_or_update https://github.com/zsh-users/zsh-autosuggestions              "$custom/plugins/zsh-autosuggestions"
  clone_or_update https://github.com/zdharma-continuum/fast-syntax-highlighting "$custom/plugins/fast-syntax-highlighting"
  clone_or_update https://github.com/Aloxaf/fzf-tab                             "$custom/plugins/fzf-tab"
  clone_or_update https://github.com/zsh-users/zsh-history-substring-search     "$custom/plugins/zsh-history-substring-search"
  clone_or_update https://github.com/MichaelAquilina/zsh-you-should-use         "$custom/plugins/you-should-use"
  clone_or_update https://github.com/romkatv/powerlevel10k                      "$custom/themes/powerlevel10k"
}

install_nvchad() {
  [[ $DO_NVCHAD -eq 1 ]] || { skip "NvChad (--no-nvchad)"; return 0; }
  step "Installing NvChad"
  if [[ -d "$HOME/.config/nvim" ]]; then
    skip "existing Neovim config found, leaving it alone"
    return 0
  fi
  git clone --quiet https://github.com/NvChad/starter "$HOME/.config/nvim" \
    && info "cloned NvChad starter, run 'nvim' to finish setup" \
    || FAILED_PKGS+=("NvChad")

  # Distro Neovim builds often lag behind what NvChad needs.
  if have nvim; then
    local v; v="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    if [[ -n "$v" ]] && awk "BEGIN{exit !($v < 0.10)}"; then
      NOTES+=("Neovim $v is older than NvChad needs (0.10+). Use the AppImage or a PPA build.")
    fi
  fi
}

# tealdeer below 1.8.0 downloads a page archive that no longer exists and fails
# to unzip the 404 body. Package managers often ship older than that. See
# https://github.com/zswizzle00/ghostty_config/issues/2
tealdeer_version() {
  have tldr || return 1
  tldr --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

tealdeer_is_current() {
  local v; v="$(tealdeer_version)" || return 1
  [[ -n "$v" ]] || return 1
  [[ "$(printf '%s\n1.8.0\n' "$v" | sort -V | head -1)" == "1.8.0" ]]
}

write_zshrc() {
  step "Writing ~/.zshrc"
  backup "$HOME/.zshrc"
  cp "$REPO_ROOT/config/zsh/zshrc" "$HOME/.zshrc"
  info "wrote ~/.zshrc"
}

# $1 is the OS-specific file in config/ghostty that goes after the shared one.
write_ghostty_config() {
  step "Writing Ghostty config"
  local src="$REPO_ROOT/config/ghostty"
  # Ghostty reads the XDG path on macOS too, so one location works on both OSes.
  local cfg="$HOME/.config/ghostty/config"
  mkdir -p "$(dirname "$cfg")"
  backup "$cfg"

  {
    printf '# Built by the bootstrap scripts from config/ghostty/config and config/ghostty/%s.\n' "$1"
    printf '# Edits here are overwritten on the next run.\n\n'
    cat "$src/config" "$src/$1"
  } > "$cfg"
  info "wrote $cfg"

  if have ghostty; then
    local errs
    errs="$(ghostty +show-config 2>&1 >/dev/null | grep -vi '^$' || true)"
    if [[ -n "$errs" ]]; then
      warn "Ghostty reported config problems:"
      printf '      %s\n' "$errs"
    else
      info "Ghostty parsed the config cleanly"
    fi
  fi
}

post_install() {
  setup_tealdeer
  if [[ "$SHELL" != *zsh ]] && have zsh; then
    NOTES+=("Login shell is $SHELL. Switch with: chsh -s \"\$(command -v zsh)\"")
  fi
  NOTES+=("Run 'p10k configure' to style the prompt.")
  NOTES+=("Machine-specific settings go in ~/.zshrc.local")
}

summary() {
  printf '\n%s%s Done.%s\n' "$BOLD" "$GREEN" "$RESET"
  if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
    printf '\n%sNot installed:%s\n' "$YELLOW" "$RESET"
    local p; for p in "${FAILED_PKGS[@]}"; do printf '  - %s\n' "$p"; done
    [[ -n "$FAILED_HINT" ]] && printf '  %s%s%s\n' "$DIM" "$FAILED_HINT" "$RESET"
  fi
  if [[ ${#NOTES[@]} -gt 0 ]]; then
    printf '\n%sNotes:%s\n' "$BOLD" "$RESET"
    local n; for n in "${NOTES[@]}"; do printf '  - %s\n' "$n"; done
  fi
  printf '\n%sNext:%s exec zsh\n\n' "$BOLD" "$RESET"
}

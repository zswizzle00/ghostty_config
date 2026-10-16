# Terminal setup

Ghostty config, zsh config, and the bootstrap scripts that set up the same
terminal environment on macOS and on Debian/Ubuntu. The scripts install CLI
tools, oh-my-zsh with plugins, powerlevel10k, and a Nerd Font, then write
`~/.zshrc` and a Ghostty config from the files in `config/`.

## Install

Clone the repo and run `install.sh`. It detects the OS and runs the matching
script in `scripts/`.

```sh
git clone https://github.com/zswizzle00/ghostty_config.git
cd ghostty_config
./install.sh
exec zsh
```

On first launch powerlevel10k runs a setup wizard and writes `~/.p10k.zsh`.
Run `p10k configure` any time to redo it.

To only use the Ghostty config, copy `config/ghostty/config` and append
`config/ghostty/macos` or `config/ghostty/linux`:

```sh
mkdir -p ~/.config/ghostty
cat config/ghostty/config config/ghostty/macos > ~/.config/ghostty/config
```

## Repo layout

| Path | Contents |
| --- | --- |
| `install.sh` | Detects the OS and runs the right bootstrap script |
| `scripts/bootstrap-macos.sh` | macOS installs, with Homebrew |
| `scripts/bootstrap-debian.sh` | Debian and Ubuntu installs, with apt |
| `scripts/lib/common.sh` | Helpers and steps both scripts share |
| `config/ghostty/config` | Ghostty settings for every OS |
| `config/ghostty/macos`, `config/ghostty/linux` | Per-OS Ghostty settings, appended to the shared file |
| `config/zsh/zshrc` | Installed as `~/.zshrc` on both OSes |
| `config/zsh/zshrc.local.example` | Starting point for `~/.zshrc.local` |

To change a setting for everyone, edit the file in `config/` and rerun with
`--configs-only`. The scripts copy these files, they don't symlink them, so
edits made directly to `~/.zshrc` or `~/.config/ghostty/config` are backed up
and replaced on the next run.

## Options

Pass these to `install.sh` or to either bootstrap script.

| Flag | Effect |
| --- | --- |
| `--minimal` | core CLI tools only, skip the extras |
| `--with-gui` | also install GUI apps |
| `--all-fonts` | install seven more Nerd Fonts, not just Meslo |
| `--no-nvchad` | skip the Neovim/NvChad step |
| `--configs-only` | only rewrite `.zshrc` and the Ghostty config |

Both scripts are safe to re-run. Configs are backed up with a timestamp, git
repos are pulled rather than re-cloned, and an existing `~/.config/nvim` is
left alone.

## What gets installed

macOS installs with Homebrew, except for `bun` and `ty`, which use the same
sources as on Debian. Debian uses apt where a package exists and the source
listed in the table where it doesn't.

### Core CLI tools

Always installed, unless you pass `--configs-only`.

| Tool | What it's for | Debian source |
| --- | --- | --- |
| `git` | Version control | apt |
| `zsh`, `curl`, `unzip`, `fontconfig` | Prerequisites for the rest of the setup | apt (macOS ships these) |
| `ripgrep` (`rg`) | Fast recursive search | apt |
| `fd` | Fast `find` replacement | apt, as `fdfind` |
| `bat` | `cat` with syntax highlighting | apt, as `batcat` |
| `fzf` | Fuzzy finder for files, history, and tab completion | apt |
| `jq` | JSON processor | apt |
| `tree` | Directory tree listing | apt |
| `eza` | `ls` replacement with icons | apt (Debian 13+, Ubuntu 24.04+) |
| `zoxide` | `cd` that remembers frequent directories | apt (Debian 13+, Ubuntu 24.04+) |
| `tealdeer` (`tldr`) | Short, example-based man pages | apt, or a release binary if apt's is older than 1.8.0 |
| `fastfetch` | System info summary | apt (Debian 13+, Ubuntu 24.04+) |
| `htop`, `btop` | Process and resource monitors | apt |
| `cowsay`, `lolcat` | Terminal fun | apt |
| `neovim` | Editor, set as `$EDITOR` | apt |
| `tree-sitter` | Parser generator that Neovim plugins use | macOS only |
| `uv` | Python package and project manager | Astral install script |

### Extra CLI tools

Installed by default. Pass `--minimal` to skip them.

| Tool | What it's for | Debian source |
| --- | --- | --- |
| `gh` | GitHub CLI | apt |
| `gitleaks` | Scans repos for committed secrets | GitHub release binary |
| `lsd` | Another `ls` replacement | apt |
| `glow` | Renders Markdown in the terminal | GitHub release binary |
| `fortune` | Random quotes | apt (`fortune-mod`) |
| `magic-wormhole` | Sends files between computers | apt |
| `opentofu` (`tofu`) | Open source Terraform | OpenTofu install script |
| `scrcpy` | Mirrors and controls an Android device | apt |
| `bun` | JavaScript runtime and package manager | Bun install script |
| `ty` | Python type checker | `uv tool install` |

### Shell

Always installed, unless you pass `--configs-only`.

| Component | What it does |
| --- | --- |
| oh-my-zsh | zsh framework that loads the plugins and theme |
| powerlevel10k | Prompt theme, configured with `p10k configure` |
| zsh-vi-mode | Vi keybindings on the command line |
| fzf-tab | Replaces the tab completion menu with fzf |
| zsh-autosuggestions | Suggests commands from history as you type |
| fast-syntax-highlighting | Colors commands as you type them |
| zsh-history-substring-search | Up and down arrows search history for what you've typed |
| you-should-use | Reminds you when an alias exists for a command you typed |

### Fonts

MesloLGS Nerd Font is always installed, because the Ghostty config and
powerlevel10k expect it. With `--all-fonts`, the scripts also install the Nerd
Font versions of FiraCode, JetBrains Mono, Hack, Cascadia Code, Source Code
Pro, Ubuntu Mono, and Iosevka. On Debian, fonts go in `~/.local/share/fonts`.

### Neovim

The scripts clone the [NvChad](https://nvchad.com) starter config into
`~/.config/nvim`. Run `nvim` once to finish the setup. If `~/.config/nvim`
already exists, the scripts leave it alone. Pass `--no-nvchad` to skip this
step.

### GUI apps

Installed only with `--with-gui`.

| App | macOS | Debian |
| --- | --- | --- |
| Ghostty | Yes | No official package, see ghostty.org |
| VLC | Yes | Yes |
| Sublime Text, Sublime Merge | Yes | Yes, from Sublime's apt repo, which the script adds |
| PowerShell | Yes | No, needs a vendor apt repo |
| Google Cloud CLI (`gcloud`) | Yes | No, needs a vendor apt repo |
| Shottr (screenshots) | Yes | flameshot instead |
| UTM (virtual machines) | Yes | virt-manager instead |
| Alfred (launcher) | Yes | No |

## What gets configured

The scripts write two files from `config/`. Any existing file is first backed
up as `FILE.bak.TIMESTAMP`.

### Ghostty: `~/.config/ghostty/config`

Built from `config/ghostty/config` plus the file for your OS. On macOS the
script also moves aside any config in `~/Library/Application Support`, which
would otherwise override this one.

| Setting | Value |
| --- | --- |
| Theme | Catppuccin Mocha |
| Font | MesloLGS Nerd Font Mono, 14 pt (thickened on macOS) |
| Padding | 12 px on each side |
| Cursor | Block, no blink |
| Mouse | Hidden while typing |
| Background | 92% opacity with blur on macOS, 95% on Linux |
| Shift+Enter | Sends Esc+Enter, which inserts a newline instead of submitting in zsh and tools like Claude Code |
| SSH | Installs Ghostty's terminfo on remote hosts automatically |
| Quick terminal | Option+backquote on macOS, Alt+backquote on Linux, from any app |
| Window | Tabs in the title bar on macOS. Single instance on Linux |

The global quick terminal hotkey needs Accessibility permission on macOS. On
Linux it needs Ghostty 1.2 or newer and an XDG desktop portal, and it doesn't
work on GNOME Wayland.

### zsh: `~/.zshrc`

Copied from `config/zsh/zshrc`.

- **Plugins:** the shell plugins listed earlier, plus the oh-my-zsh `git`,
  `jsontools`, `extract`, and `safe-paste` plugins. The `macos` or `debian`
  plugin, and the `fzf`, `zoxide`, `gh`, `bun`, `gcloud`, `sublime`, and
  `poetry` plugins, load only when they're available. A missing plugin is
  skipped instead of printing a warning.
- **History:** 50,000 entries, shared between open shells, with duplicates
  and commands that start with a space left out.
- **PATH:** adds Homebrew, `~/.local/bin`, and `~/.bun/bin`.
- **Environment:** `EDITOR` and `VISUAL` set to `nvim`, `LANG` set to
  `en_US.UTF-8`.
- **Local overrides:** sources `~/.zshrc.local` near the end, so settings
  there win.

Aliases are defined only when the tool they call is installed:

| Alias | Runs |
| --- | --- |
| `ls` | `eza --icons --group-directories-first` |
| `ll` | `eza -lah --icons --group-directories-first` |
| `lt` | `eza --tree --level=2 --icons` |
| `vim` | `nvim` |
| `ff` | `fastfetch` |
| `md` | `glow` |
| `tf` | `tofu` |
| `secrets` | `gitleaks detect --source . -v` |
| `bat`, `fd` | `batcat`, `fdfind` on Debian |
| `zshrc` | Opens `~/.zshrc` in your editor, then reloads the shell |
| `ghconf` | Opens the Ghostty config in your editor |

The `ssh-terminfo user@host` function copies Ghostty's terminfo to a remote
host by hand, for cases the automatic SSH integration misses.

## Editing things afterwards

| What | Where |
| --- | --- |
| prompt | `p10k configure`, or edit `~/.p10k.zsh` |
| terminal colors, font, padding | `~/.config/ghostty/config` |
| aliases, plugins, shell behavior | `~/.zshrc` |
| anything you don't want overwritten | `~/.zshrc.local` |

`~/.zshrc.local` is sourced at the end of `.zshrc` and is never touched on a
re-run. Put machine-specific settings there. `config/zsh/zshrc.local.example`
has a few examples.

There are two aliases for this: `zshrc` opens `.zshrc` and reloads, `ghconf`
opens the Ghostty config.

## Things that are easy to get wrong

**Ghostty has no plugin system.** The `plugins=(...)` array is oh-my-zsh, read
from `.zshrc`. Ghostty just runs the shell.

**Plugin order matters.** fzf-tab has to load before anything that wraps
widgets, and history-substring-search goes last. zsh-vi-mode also wipes
keybindings when it initializes, so the up/down bindings are re-applied in a
`zvm_after_init` hook. Both are handled in `config/zsh/zshrc`.

**Everything personal goes below `source $ZSH/oh-my-zsh.sh`.** Aliases set
above that line get overwritten by oh-my-zsh's own.

**Ghostty theme names are the iTerm2 ones.** Capitalized, with spaces, no
quotes: `theme = Catppuccin Mocha`, not `catppuccin-mocha`. Check with
`ghostty +list-themes`.

**Ghostty config lives in two possible places on macOS.**
`~/Library/Application Support/com.mitchellh.ghostty/config` and
`~/.config/ghostty/config`. If both exist the first wins. The script writes the
XDG one and moves any Application Support config aside, so a Mac and a Linux
box can share the same file.

**One setting per line.** Cramming two `keybind` lines onto one line makes
Ghostty swallow them into the previous value.

**Key names.** The backtick key is `backquote`, not `grave`. A wrong key name
gives `error.InvalidFormat`.

**`ghostty +show-config`** prints what Ghostty actually parsed. The scripts run
it after writing the config and report any errors.

## Known issues

Known issues and deliberately excluded tools are tracked in
[GitHub issues](https://github.com/zswizzle00/ghostty_config/issues).

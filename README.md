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

**Core:** ripgrep, fzf, jq, tree, eza, zoxide, tealdeer, uv, fd, bat, htop,
btop, fastfetch, cowsay, lolcat, neovim, git, tree-sitter

**Extras:** gh, gitleaks, lsd, bun, glow, fortune, magic-wormhole, opentofu,
scrcpy, ty

**Shell:** oh-my-zsh, powerlevel10k, zsh-vi-mode, fzf-tab, zsh-autosuggestions,
fast-syntax-highlighting, zsh-history-substring-search, you-should-use

**GUI (`--with-gui`):** on macOS, Ghostty, VLC, PowerShell, Shottr, Sublime
Text, Sublime Merge, gcloud, Alfred, UTM. On Debian, VLC, flameshot,
virt-manager, Sublime Text and Sublime Merge (from Sublime's apt repo, which
the script adds). Shottr, Alfred and UTM are macOS only. PowerShell and gcloud
need vendor apt repos, which the script does not add.

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

**`'xterm-ghostty': unknown terminal type` over SSH.** Ghostty advertises a
TERM the remote host has never heard of. The config sets
`shell-integration-features = ssh-env,ssh-terminfo`, which installs Ghostty's
terminfo on each host the first time you connect. It needs `tic` on the remote,
and does not cover scripts, mosh or jump hosts. For those, run `ssh-terminfo
user@host`, a function in `config/zsh/zshrc`. Restart Ghostty fully after
changing shell integration settings, a config reload is not enough.

**`tldr --update` fails with "could not find central directory end".**
tealdeer below 1.8.0 asks for a page archive that no longer exists upstream and
tries to unzip the 404 response. Distro packages are often older than that. The
scripts detect the version, try a package manager upgrade, and on Debian fall
back to a release binary in `~/.local/bin`. Background:
https://github.com/tealdeer-rs/tealdeer/issues/459

**Quick terminal hotkey does nothing on Linux.** Global keybinds need Ghostty
1.2 or newer and a working XDG desktop portal, and they are not supported on
GNOME Wayland yet. Drop the `global:` prefix and the bind works while Ghostty
is focused.

**NvChad wants Neovim 0.10 or newer.** The Debian script warns if apt's version
is older. Use the AppImage or a PPA build.

**No Ghostty package on Debian.** The script writes the config either way. See
ghostty.org for community builds.

## Deliberately excluded

`zsh-autocomplete` replaces zsh's completion system and conflicts with fzf-tab.
`zsh-syntax-highlighting` is superseded by fast-syntax-highlighting. Running
either alongside these breaks tab completion or double-highlights the prompt.

`neofetch` is archived. `fastfetch` is the drop-in replacement.

`brew tap homebrew/cask-fonts` is no longer needed. Font casks are in
homebrew/cask now.

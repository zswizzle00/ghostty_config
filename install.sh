#!/usr/bin/env bash
#
# install.sh - run the bootstrap script for this OS. Takes the same flags.
#

set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

case "$(uname -s)" in
  Darwin) exec "$dir/bootstrap-macos.sh" "$@" ;;
  Linux)
    [[ -f /etc/debian_version ]] && exec "$dir/bootstrap-debian.sh" "$@"
    echo "Only Debian and Ubuntu are supported on Linux. Install the packages yourself, then run scripts/bootstrap-debian.sh --configs-only." >&2
    exit 1 ;;
  *)
    echo "Unsupported OS: $(uname -s). Use macOS, Debian, or Ubuntu." >&2
    exit 1 ;;
esac

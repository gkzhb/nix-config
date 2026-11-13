#!/bin/bash
# Prune only the selected system profile, then GC respecting all other roots.
# The launchd job supplies immutable Nix binaries and the system profile path.
set -euo pipefail

if [[ $# -ne 2 || "$1" != /* || "$2" != /* ]]; then
    echo "Usage: nix-darwin-gc.sh /absolute/nix/bin /absolute/system-profile" >&2
    exit 2
fi
nix_bin="$1"
profile="$2"

if [[ ! -L "$profile" || ! -e "$profile" ]]; then
    echo "System profile missing or broken; skipping cleanup: $profile" >&2
    exit 1
fi

printf 'Nix system cleanup started at %s; keeping current + 5 historical generations\n' "$(/bin/date -Iseconds)"
# +6 includes the current generation. On rollback, Nix also protects newer ones.
"$nix_bin/nix-env" --profile "$profile" --delete-generations +6
# No -d: do not delete any other system/user profile history.
"$nix_bin/nix-store" --gc
printf 'Nix system cleanup completed at %s\n' "$(/bin/date -Iseconds)"

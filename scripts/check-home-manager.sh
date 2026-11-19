#!/bin/sh
# Read-only verification of system-level Home Manager activation units.
# Usage: sh scripts/check-home-manager.sh USER [USER ...]
set -eu

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 USER [USER ...]" >&2
    exit 2
fi
for user do
    if [ -z "$user" ]; then
        echo "Home Manager username must not be empty." >&2
        exit 2
    fi
done

result=0
for user do
    unit="home-manager-${user}.service"
    if systemctl is-active --quiet "$unit"; then
        printf "Home Manager service is active: %s\n" "$unit"
    else
        printf "Home Manager activation check failed: %s\n" "$unit" >&2
        systemctl --no-pager --full status "$unit" >&2 || :
        journalctl --boot --unit "$unit" --no-pager --lines 80 >&2 || :
        result=1
    fi
done
exit "$result"

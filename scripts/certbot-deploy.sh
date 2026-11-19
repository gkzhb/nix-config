#!/usr/bin/env bash
# Called only by Certbot's deploy hook after successful renewal.
set -euo pipefail

# Scope this hook to the shared devbox certificate, even if reused elsewhere.
if [[ ${RENEWED_LINEAGE:-} != /etc/letsencrypt/live/byte.gkzhb.top ]]; then
    exit 0
fi

systemctl=$1
# Neither operation starts an inactive service. Dolt's systemd credentials are
# snapshots, so it needs a restart rather than a reload to see the new key.
status=0
"$systemctl" try-reload-or-restart nginx.service || status=$?
"$systemctl" try-restart dolt.service || status=$?
exit "$status"

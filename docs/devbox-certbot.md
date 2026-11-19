# devbox Certbot systemd timer

`hosts/devbox/modules/certbot.nix` replaces the root cron schedule with
`certbot-renew.timer`, managed by System Manager. VPS configuration is unchanged.

- Schedule: **monthly on day 1 at 03:00**, in the host's timezone, matching the
  previous `0 3 1 * *` cron. `Persistent = true` catches missed runs after downtime.
- Only the timer starts the root oneshot service; activation does not directly
  request a renewal (a missed persistent timer run may fire on activation).
- Uses the existing `/home/zhanghaibin.zhb/.local/bin/certbot` uv installation
  and `renew --cert-name byte.gkzhb.top --non-interactive`. Certbot decides whether
  renewal is due; it does not force issuance on every timer run.
- Reuses `/etc/letsencrypt/renewal/byte.gkzhb.top.conf` and its existing
  Cloudflare credential path. No credential/key material is read into the Nix
  store, copied or given broader permissions. The pinned nixpkgs Cloudflare
  plugin is marked broken, so this migration intentionally retains uv Certbot.
- The successful-renewal deploy hook reloads running nginx and restarts running
  Dolt to refresh its systemd credential snapshots. Inactive services stay
  inactive. Failed or skipped renewals do not trigger this hook.
- Logs are in the journal, not `/var/log/certbot_cron.log`.

Monthly scheduling preserves the original behavior, but has a narrow renewal
window: a failed run is not retried until the next month. For better expiry
protection, change `OnCalendar` to `*-*-* 03:00:00` (daily checks); Certbot still
renews only when due.

## Migrate and verify

Review the flake caches/public keys before activation. First back up root's
crontab and remove **only** this legacy line with `sudo crontab -e`, preserving
other jobs:

```text
0 3 1 * * /home/zhanghaibin.zhb/scripts/certbot/create.fish >> /var/log/certbot_cron.log 2>&1
```

Then activate and check the timer and Home Manager separately:

```sh
just build-devbox
systemctl status certbot-renew.timer home-manager-zhanghaibin.zhb.service --no-pager
systemctl list-timers --all certbot-renew.timer
journalctl -u certbot-renew.service -n 50 --no-pager
sudo crontab -l
```

If activation fails, restore the old cron until the timer is working. Do not
leave both schedulers enabled. Existing user Certbot, its DNS plugin, renewal
config, account and credentials must remain installed/accessible to root.

Optional validation below contacts the staging ACME server and creates DNS
challenge records; it is **not** an offline regression test. By default dry-run
does not execute the deploy hook (do not add `--run-deploy-hooks` unless you
intend to reload/restart live services):

```sh
sudo /home/zhanghaibin.zhb/.local/bin/certbot renew --cert-name byte.gkzhb.top --non-interactive --dry-run
```

For a real due-renewal check with the hook, run
`sudo systemctl start certbot-renew.service`. An inactive Dolt is deliberately
not started by renewal; its next normal start reads the new certificates.

## Offline regression checks

`just test-certbot` evaluates service/timer wiring and runs the deploy hook
against a fake systemctl. It does not activate the host, renew certificates,
read credentials, mutate cron or restart real services.

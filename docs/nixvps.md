# nixvps

Linode VPS (x86_64, QEMU/KVM) running [Vaultwarden] behind Caddy, backed up
nightly to Backblaze B2 with restic.

## Services

| Service | Where | Reached at |
|---|---|---|
| Vaultwarden | `127.0.0.1:8222` | `https://vault.jukeluke.com`, Cloudflare-proxied |
| Caddy | `:80`, `:443` | Reverse proxy with HSTS, `nosniff`, referrer and permissions headers |
| restic | timer, 03:00 daily | `b2:jukeluke-vaultwarden-backup:` |

Caddy trusts Cloudflare's edge ranges (`common/cloudflare-ranges.nix`,
shared with calliope) as proxies and reads the client IP from
`CF-Connecting-IP`, which it forwards to Vaultwarden as `X-Real-IP`. The same
range list is fail2ban's `ignoreip`, so a burst of bad logins bans the real
client rather than a Cloudflare edge.

Signups and the admin panel are disabled. Mail goes out through Migadu.

## Security

From `common/server-base.nix`, like every server:

- SSH on port `47291`, key-only, `luke` only, no root login, no forwarding
- fail2ban with escalating bans (1 h doubling to a week)

Plus a Vaultwarden-specific fail2ban jail that watches the journal for failed
logins (5 tries).

Vaultwarden's secret environment is a sops secret mounted at
`/run/secrets/vaultwarden.env`; see [Keys and secrets](secrets.md).

## Backups

Nightly at 03:00 (±15 min) to `b2:jukeluke-vaultwarden-backup:`, keeping
7 daily, 4 weekly and 6 monthly snapshots. The set is:

- the SQLite database, captured with `sqlite3 .backup` into
  `/var/backup/vaultwarden/` so restic never sees a half-written file
- attachments, sends and RSA keys from `/var/lib/vaultwarden`

The live `db.sqlite3*` files and the regenerable `icon_cache` are excluded.
`vaultwarden.env` is not in the backup set either: it lives in sops now, so
the encrypted copy in this repo is the authoritative one.

restic's B2 credentials and repository password are sops secrets
(`/run/secrets/restic-b2.env`, `/run/secrets/restic-password`).

### Restore

```bash
restic-vaultwarden snapshots
restic-vaultwarden restore latest --target /tmp/vw-restore
sqlite3 /tmp/vw-restore/var/backup/vaultwarden/db.sqlite3 "PRAGMA integrity_check;"

systemctl stop vaultwarden
cp -a /tmp/vw-restore/var/lib/vaultwarden/. /var/lib/vaultwarden/
cp /tmp/vw-restore/var/backup/vaultwarden/db.sqlite3 /var/lib/vaultwarden/db.sqlite3
rm -f /var/lib/vaultwarden/db.sqlite3-wal /var/lib/vaultwarden/db.sqlite3-shm
chown -R vaultwarden:vaultwarden /var/lib/vaultwarden
systemctl start vaultwarden
```

[Vaultwarden]: https://github.com/dani-garcia/vaultwarden

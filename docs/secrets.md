# Keys and secrets

## Keys

`keys/` holds public keys only. Everything in it is safe to publish.

| File | Purpose |
|---|---|
| `luke-nixnotdix.pub` | Admin key. Installed into `authorized_keys` on every server by `common/server-base.nix`, and the admin sops recipient |
| `nixvps.host.pub`, `nixcraft.host.pub`, `calliope.host.pub` | Server SSH host keys. Pinned as `programs.ssh.knownHosts` on nixnotdix, and each host's sops recipient |
| `github.com.pub` | GitHub's host key, pinned so the `git push` at the end of `./rebuild` never prompts |

Private keys never leave the machine that generated them. Servers pull this
repo over HTTPS (it is public), so they hold no key for it at all. Pinning
the host keys means a reinstalled server fails loudly instead of prompting,
and that a reinstall must seed the old host key, or the pin has to be
updated. See each host's install notes.

To add an admin device, drop its public key in `keys/` and list it in
`common/server-base.nix`.

## Secrets

Secrets live encrypted under `secrets/`, managed with [sops-nix]. Each host
decrypts its own secrets at activation using its SSH host key, so no key
material is ever placed on a host by hand. Recipients are declared in
`.sops.yaml`: the admin key plus the one host that needs the file.

| Secret | Host | Mounted at |
|---|---|---|
| `secrets/nixvps/vaultwarden.env` | nixvps | `/run/secrets/vaultwarden.env` |
| `secrets/nixvps/restic-b2.env` | nixvps | `/run/secrets/restic-b2.env` |
| `secrets/nixvps/restic-password` | nixvps | `/run/secrets/restic-password` |
| `secrets/nixcraft/users.yaml` | nixcraft | `/run/secrets-for-users/luke-hashed-password` |
| `secrets/calliope/cloudflare.env` | calliope | `/run/secrets/cloudflare.env` |
| `secrets/calliope/wg-qb.conf` | calliope | `/run/secrets/wg-qb.conf` |
| `secrets/calliope/radarr.yaml` | calliope | `/run/secrets/radarr-api-key` (bare key, for Recyclarr); templated into `/run/secrets/rendered/radarr.env` for Radarr |
| `secrets/calliope/sonarr.yaml` | calliope | `/run/secrets/sonarr-api-key` (bare key, for Recyclarr); templated into `/run/secrets/rendered/sonarr.env` for Sonarr |

`.env` secrets use sops' `dotenv` format, so variable *names* stay readable
in git and only values are encrypted. They are mounted whole (`key = ""`) so
systemd can consume them as an `EnvironmentFile`. The `.yaml` secrets are
YAML rather than dotenv on purpose: sops-nix ignores `key` for dotenv and
hands over the whole `KEY=value` line, and Recyclarr needs the bare key.

`cloudflare.env` and `wg-qb.conf` were committed as encrypted `REPLACE_ME`
placeholders so the configuration evaluates before the real values exist.
Fill them in before expecting certificates or the torrent tunnel to work;
see [calliope: media services](calliope-media.md#one-time-setup).

### Editing a secret

```bash
sops secrets/nixvps/vaultwarden.env
```

Editing in place needs a *decryption* key, and that is only available in two
places:

- **On nixnotdix**, as `luke`. The admin recipient is derived from
  `keys/luke-nixnotdix.pub`, and home-manager sets `SOPS_AGE_KEY_CMD` to
  `ssh-to-age -private-key`. The recipient is the *converted* X25519 key, so
  sops will not match a raw SSH key against it (“identity did not match any
  of the recipients”).
- **On a server, as root**, through the host key. The host key is
  `0600 root:root`, so as `luke` there is no usable identity and sops fails
  with “Failed to get the data key”. As root, chown the file back afterwards:

  ```bash
  sudo SOPS_AGE_KEY_CMD="$(which ssh-to-age) -private-key -i /etc/ssh/ssh_host_ed25519_key" \
    EDITOR=vim $(which sops) secrets/calliope/cloudflare.env
  sudo chown luke:users secrets/calliope/cloudflare.env
  ```

  Don't use `SOPS_AGE_SSH_PRIVATE_KEY_FILE` for this; it hands sops the raw
  SSH key and fails with the same recipient mismatch.

*Encryption* needs only the public recipients in `.sops.yaml`, so a secret
can be replaced from anywhere without a key. Overwrite and re-encrypt rather
than editing in place:

```bash
: > secrets/calliope/wg-qb.conf
vim secrets/calliope/wg-qb.conf        # paste the new contents
sops encrypt --input-type binary --output-type binary --in-place secrets/calliope/wg-qb.conf
sops filestatus secrets/calliope/wg-qb.conf        # {"encrypted":true}
```

Drop the `--input-type`/`--output-type` flags for `.env` and `.yaml` files,
whose format sops infers from the extension.

### Adding a host

1. Convert the new host's SSH host public key with `ssh-to-age` and add it to
   `.sops.yaml`, with a `creation_rules` entry for `secrets/<host>/`.
2. Run `sops updatekeys` on any existing file the host needs.
3. Commit the host public key to `keys/` and pin it in nixnotdix's
   `programs.ssh.knownHosts`.

### The pre-commit hook

`secrets/` cannot be guarded by `.gitignore` (re-including the encrypted
files re-includes everything), so a tracked hook,
[`.githooks/pre-commit`](../.githooks/pre-commit), rejects any staged file
under `secrets/` that `sops filestatus` does not report as encrypted. It
checks the staged blob, not the working tree. Enable it once per clone:

```bash
just hooks          # git config core.hooksPath .githooks
just check-secrets  # the same check over everything already committed
```

Every host installs `sops` and `ssh-to-age` system-wide so the hook works
from a plain shell, not just inside a dev shell.

[sops-nix]: https://github.com/Mic92/sops-nix

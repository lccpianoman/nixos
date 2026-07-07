# NixOS repo audit checklist

Created from the full repo audit on 2026-07-02. Check items off as they are handled.

Priority guide:

- `P0`: data-loss, root-access, or deployment-safety risk
- `P1`: important security/reliability/maintainability improvement
- `P2`: medium cleanup or quality improvement
- `P3`: nice-to-have polish

## P0 - Do first

- [x] Implement automated Vaultwarden backups.
  - [x] Pick backup tool and destination: Restic → Backblaze B2 (bucket `jukeluke-vaultwarden-backup`).
  - [x] Back up `/var/lib/vaultwarden`, including SQLite DB (via `sqlite3 .backup` staging), attachments, sends, and `vaultwarden.env`. Icon cache excluded (regenerable).
  - [x] Schedule backups with a NixOS systemd service/timer (`services.restic.backups.vaultwarden`, nightly 03:00).
  - [x] Encrypt backups before they leave the VPS (restic encrypts client-side; password in `/var/lib/restic/password`).
  - [x] Add backup retention policy (7 daily / 4 weekly / 6 monthly).
  - [x] Document restore steps in `README.md`.
  - [x] Test restoring to a temporary location and verify the DB is usable. *(Done 2026-07-06: snapshot 68ab0570 restored to /tmp/vw-restore, `PRAGMA integrity_check` = ok.)*

- [x] Remove passwordless sudo from the VPS.
  - [x] Change `security.sudo.wheelNeedsPassword = false;` in `hosts/nixvps/configuration.nix`. *(Line removed; default is `true`. Luke confirmed his account password is set.)*
  - [x] If passwordless sudo is still needed, replace the global setting with narrow `security.sudo.extraRules`. *(N/A — not needed.)*
  - [x] Confirm `luke` still has a usable sudo path after deployment. *(Confirmed — deployed twice with password sudo after the change.)*

- [x] Decide what to do with the Vaultwarden admin panel.
  - [x] Disable `ADMIN_PANEL_ENABLED` if it is not actively needed. *(Disabled.)*
  - [x] If keeping it enabled, restrict `/admin` in Caddy with IP allowlisting or extra auth. *(N/A — disabled instead.)*
  - [x] Confirm `ADMIN_TOKEN` is stored only in `/var/lib/vaultwarden/vaultwarden.env`. *(Verified — no secret values anywhere in the repo.)*
  - [x] Confirm `ADMIN_TOKEN` is an Argon2 hash, not a plain token. *(Checked on the VPS: it is a plain token. Inert while the panel is disabled; if re-enabling, replace it with output of `vaultwarden hash` first.)*

- [x] Harden the `rebuild` script.
  - [x] Change `set -e` to `set -euo pipefail`.
  - [x] Validate `TARGET_HOST` against known hosts or a strict hostname regex. *(Both: regex + existing `hosts/` dir check.)*
  - [x] Check that `nh`, `git`, `grep`, and `awk` are available before doing work.
  - [x] Fail clearly if `nh os switch` or `nh os boot` fails.
  - [x] Parse the current generation robustly and fail if it cannot be determined. *(Matches the `(current)` line, validates numeric.)*
  - [x] Do not treat every `git commit` failure as "No changes to commit". *(Checks `git diff --cached --quiet` first; real commit failures now propagate.)*
  - [x] Consider refusing `./rebuild nixvps` unless running on `nixvps`. *(Refuses any target that isn't the current hostname — nh activates locally, so cross-host targets were dangerous.)*

- [x] Expand `.gitignore` to reduce accidental secret commits.
  - [x] Ignore `.env`, `.env.*`, `*.key`, `*.pem`, `*.secret`, `*.pass`, `*.pw`.
  - [x] Ignore `secrets/`, `private/`, and other local secret directories.
  - [x] Explicitly ignore `vaultwarden.env`.
  - [x] Ignore local OpenWeatherMap key files if they might ever be created inside the repo. *(`api_key`, `openweathermap*`.)* *(Verified no tracked files are caught by the new patterns.)*

## P1 - High-value improvements

- [x] Make the Caddy reverse proxy config more explicit.
  - [x] Use `reverse_proxy 127.0.0.1:8222` instead of `localhost:8222`.
  - [x] Add HSTS. *(max-age 1 year, scoped to vault.jukeluke.com, no includeSubDomains.)*
  - [x] Add basic security headers: `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, and frame policy as appropriate for Vaultwarden. *(SAMEORIGIN, matching Vaultwarden's own header.)*
  - [x] Explicitly set trusted forwarded headers for Vaultwarden. *(Caddy sets `X-Real-IP` from the TCP peer; `IP_HEADER = "X-Real-IP"` — not client-spoofable.)*
  - [x] Verify Vaultwarden still sees correct client IPs after the header changes. *(Confirmed post-deploy. Required a follow-up fix: the site is Cloudflare-proxied, so Caddy now trusts CF ranges and resolves the client from CF-Connecting-IP; fail2ban `ignoreip`s CF ranges so it can never ban an edge.)*

- [x] Add SSH hardening on the VPS if the features are not needed.
  - [x] Set `AllowAgentForwarding = false`.
  - [x] Set `AllowTcpForwarding = false`. *(Note: this disables `ssh -L` tunnels to the VPS — revert this one line if tunneling is ever wanted.)*
  - [x] Set `X11Forwarding = false`.
  - [x] Set `PermitTunnel = "no"`.
  - [x] Add `ClientAliveInterval` and `ClientAliveCountMax` if idle session cleanup is desired. *(300s × 3 — drops dead sessions after ~15 min.)*

- [x] Decide whether `nix.settings.trusted-users = [ "luke" ];` is necessary on the VPS.
  - [x] Keep it only if trusted Nix operations as `luke` are required. *(Removed — deploys go through sudo/root, which is always trusted. Restore if `nix copy` to the VPS as `luke` is ever needed.)*
  - [x] Document why it is needed if it stays. *(N/A — removed.)*

- [x] Make NUR follow the main nixpkgs input.
  - [x] Update `flake.nix` so `nur.inputs.nixpkgs.follows = "nixpkgs";`.
  - [x] Verify the flake still evaluates. *(Both hosts' toplevel derivations instantiate; lock rewired via `nix flake lock` — no version bumps.)*

- [x] Add project quality gates.
  - [x] Add a Nix formatter via `formatter.x86_64-linux`. *(nixfmt-tree; declared but not yet run — `nix fmt` will reformat all .nix files when desired.)*
  - [x] Add or document a local check command for `nix flake check --no-build`. *(README "Checks" section; verified passing locally.)*
  - [x] Add ShellCheck coverage for `rebuild`. *(Local command documented + CI step; clean.)*
  - [x] Add Python formatting/linting for `hosts/nixnotdix/assets/weather/main.py`. *(ruff, documented + CI step; currently clean.)*
  - [x] Consider GitHub Actions or another CI workflow for flake evaluation. *(`.github/workflows/check.yml`: flake check + shellcheck + ruff on push/PR.)*

- [x] Improve weather widget reliability.
  - [x] Print a clear fallback value on API failure instead of printing nothing. *(Prints `N/A`; errors go to stderr.)*
  - [x] Exit non-zero on real weather lookup failure.
  - [x] Use `requests.get(..., params=...)` instead of manually building query strings.
  - [x] Replace generic `Mozilla/5.0` user agent with a descriptive widget user agent. *(`waybar-weather-widget/1.0`.)*
  - [x] Use a proper `Retry` strategy with backoff instead of bare `HTTPAdapter(max_retries=5)`. *(urllib3 `Retry`: total 5, backoff 1s, 429/5xx only — auth errors fail fast.)*
  *(Tested: missing key → `N/A`/exit 1, bad key → `N/A`/exit 1, real key → correct weather/exit 0.)*

- [x] Revisit Sway config validation.
  - [x] Try enabling `checkConfig = true;`. *(Enabled. Root cause of the old failure: `bg ~/.background-image` referenced $HOME, which doesn't exist in the build sandbox. `bg` now points at the wallpaper's store path directly, and the redundant `~/.background-image` symlink was removed. Validation passes.)*
  - [x] If validation must stay disabled, add a comment explaining the exact reason. *(N/A — enabled.)*

## P2 - Maintainability cleanup

- [x] Move Waybar weather files to Home Manager `xdg.configFile`.
  - [x] Replace absolute `home.file."${weatherDir}/..."` paths where practical. *(Both weather files now `xdg.configFile` with relative keys.)*
  - [x] Keep the API key file outside the Nix store and outside git. *(Already the case; now documented in a comment.)*

- [x] Centralize repeated desktop constants.
  - [x] Put monitor names, workspace mappings, weather location, VPS SSH port, and similar host constants in one obvious place. *(New `hosts/nixnotdix/constants.nix` feeds sway.nix + waybar.nix; VPS SSH port is a single `sshPort` binding used by openssh + firewall.)*
  - [x] Keep host-specific values out of shared modules. *(Verified — `common/` contains no host-specific values.)*

- [x] Improve Bash prompt compatibility.
  - [x] Avoid fully overwriting `PROMPT_COMMAND`.
  - [x] Compose with any existing prompt command so integrations like direnv can coexist cleanly. *(`__build_prompt` prepended so `$?` stays correct.)*

- [x] Document intentionally pinned state versions.
  - [x] Add a comment near `system.stateVersion = "25.11";` for `nixnotdix`.
  - [x] Add a comment near `home.stateVersion = "25.11";`.
  - [x] Do not bump these just because nixpkgs is pinned to 26.05. *(Not bumped; comments say why.)*

- [x] Replace the raw VPS IP in SSH config with DNS if available.
  - [x] Prefer a stable hostname over `66.228.49.38`. *(Reviewed — no direct DNS exists; vault.jukeluke.com is Cloudflare-proxied and an unproxied record would expose the origin IP. Keeping the static Linode IP deliberately; comment added in home.nix.)*
  - [x] Keep the custom SSH port if desired. *(Kept, 47291.)*

- [x] Document or isolate the BattlEye host blocking.
  - [x] Add a clear comment explaining why those domains are mapped to `0.0.0.0`. *(GTA V Online under Proton kicks players unless these are blocked.)*
  - [x] Consider moving them to a clearly named local policy module. *(Considered — three lines with a comment don't justify a module.)*

- [x] Trim production VPS packages.
  - [x] Decide whether `claude-code` and `github-copilot-cli` belong on a Vaultwarden VPS. *(Kept deliberately — Luke uses both to administer the VPS; comment added.)*
  - [x] Move rarely used diagnostic/dev tools to `nix shell` if they do not need to be permanently installed. *(Kept — small, useful for server admin.)*
  - [x] Keep only tools that are needed for routine server administration. *(Reviewed; list is intentional.)*

- [x] Improve Clone Hero overlay maintenance.
  - [x] Consolidate version strings so the custom version is not repeated in multiple places. *(Overlay now compares against `custom.version` — the version lives only in pkgs/clonehero.nix.)*
  - [x] Document when the local package override can be removed. *(Comment: overlay is a no-op once nixpkgs ≥ 1.1.0.6142 — still 1.1.0.6085 as of 2026-07.)*
  - [x] Keep the overlay logic simple and predictable when nixpkgs catches up. *(Self-retiring via `versionOlder`; verified it still selects 1.1.0.6142.)*

- [x] Consolidate repeated theme/color helper logic.
  - [x] Add helper functions in `theme.nix` or a small companion module for hex stripping / ANSI conversion. *(`theme.lib.stripHash`, `theme.lib.ansiRgb`.)*
  - [x] Use those helpers from Sway, Fuzzel, and Bash config. *(Verified the generated swaylock command is unchanged.)*

- [x] Improve README operational docs.
  - [x] Add backup and restore procedure.
  - [x] Add secret recovery procedure for `/var/lib/vaultwarden/vaultwarden.env`.
  - [x] Add update cadence notes for `nix flake update`. *(Monthly-ish, Luke-run.)*
  - [x] Note that Luke should run `./rebuild` locally and not from agents.

## P3 - Nice to have

- [x] Add fail2ban observability.
  - [x] Explicitly confirm the SSH jail is enabled. *(Checked live on the VPS: sshd jail active, 16 historical bans.)*
  - [x] Consider email notifications for bans. *(Considered, declined — bans are routine noise on public SSH; would add an MTA dependency for little value.)*
  - [x] Consider Vaultwarden/Caddy-specific filters if logs expose useful failed-login patterns. *(Added a vaultwarden jail: journald filter on failed logins, 5 retries. Works because IP_HEADER is now X-Real-IP.)*

- [x] Add SSH key metadata.
  - [x] Record the fingerprint for `keys/luke.pub` in a nearby comment or docs. *(In README under Structure.)*
  - [x] Verify the key type is modern, preferably Ed25519. *(Ed25519.)*

- [x] Review GRUB serial console exposure on `nixvps`.
  - [x] Decide whether Linode serial console access is acceptable as-is. *(Accepted — Lish is gated by the Linode account; comment added in hardware-configuration.nix.)*
  - [x] Consider a GRUB password only if it does not make VPS recovery painful. *(Declined — it would, and anyone with Lish access can rescue-boot anyway.)*

- [x] Improve Python weather script polish.
  - [x] Add a short module docstring.
  - [x] Add function docstrings only where they clarify behavior. *(`get_city` only.)*
  - [x] Avoid IP geolocation fallback unless it is actually useful. *(Kept — Waybar always passes `-c`, so it only affects ad-hoc CLI use, where it is useful.)*
  - [x] If IP geolocation stays, make wrong-location fallback obvious. *(stderr warnings + docstring note about VPN/ISP mislocation.)*

- [x] Reduce README / `CLAUDE.md` drift.
  - [x] Decide which file is the source of truth. *(README.md for human/operational docs; stated at the top of CLAUDE.md.)*
  - [x] Keep `CLAUDE.md` focused on agent instructions and link to README for human docs. *(Also fixed facts this audit changed: admin panel, trusted-users, backups, headers, new files.)*

- [x] Consider local pre-commit checks.
  - [x] Format Nix files.
  - [x] Run ShellCheck on shell scripts.
  - [x] Compile or lint Python scripts.
  - [x] Run `nix flake check --no-build`.
  *(Considered, declined as pre-commit hooks: CI runs all of these on every push and the same commands are documented in README "Checks" — a local hook framework would duplicate that for extra commit friction.)*

## Verification checklist for future changes

- [x] `nix flake check --no-build --no-write-lock-file` *(passing after all audit changes)*
- [x] Instantiate both system toplevel derivations without building. *(both instantiate)*
- [x] Confirm `nixvps` services start: Vaultwarden, Caddy, OpenSSH, fail2ban. *(All active post-deploy, plus the restic timer armed.)*
- [x] Confirm Vaultwarden login works after Caddy/header/admin-panel changes. *(Login works; real client IP logged.)*
- [x] Confirm Vaultwarden email invite/password-reset delivery works. *(Reviewed — no audit change touched the SMTP path: outbound direct to smtp.migadu.com:465, bypasses Caddy/firewall/fail2ban changes; SMTP_* config and env file untouched.)*
- [x] Confirm latest backup exists and can be decrypted. *(Snapshot 68ab0570, 7.45 MiB, listed and restored.)*
- [x] Confirm a test restore works before trusting the backup system. *(Restore + `PRAGMA integrity_check` = ok, 2026-07-06.)*
- [x] Confirm Sway starts and keybindings still work after desktop config changes. *(Rebuilt and in use.)*
- [x] Confirm Waybar weather shows a sensible fallback when the API key/network is unavailable. *(Tested live 2026-07-06: found Waybar hides module output when exec exits non-zero, so the module went blank instead of showing `N/A`. Fixed: weather.sh wrapper swallows the exit code (`|| true`) so `N/A` renders; script keeps non-zero exits for CLI use. Applies on next rebuild.)*


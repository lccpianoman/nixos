# NixOS repo audit checklist

Created from the full repo audit on 2026-07-02. Check items off as they are handled.

Priority guide:

- `P0`: data-loss, root-access, or deployment-safety risk
- `P1`: important security/reliability/maintainability improvement
- `P2`: medium cleanup or quality improvement
- `P3`: nice-to-have polish

## P0 - Do first

- [ ] Implement automated Vaultwarden backups.
  - [ ] Pick backup tool and destination: Restic, Borg, Linode backups/object storage, or another encrypted offsite target.
  - [ ] Back up `/var/lib/vaultwarden`, including SQLite DB, attachments, sends, icons/cache if needed, and `vaultwarden.env`.
  - [ ] Schedule backups with a NixOS systemd service/timer.
  - [ ] Encrypt backups before they leave the VPS.
  - [ ] Add backup retention policy.
  - [ ] Document restore steps in `README.md`.
  - [ ] Test restoring to a temporary location and verify the DB is usable.

- [ ] Remove passwordless sudo from the VPS.
  - [ ] Change `security.sudo.wheelNeedsPassword = false;` in `hosts/nixvps/configuration.nix`.
  - [ ] If passwordless sudo is still needed, replace the global setting with narrow `security.sudo.extraRules`.
  - [ ] Confirm `luke` still has a usable sudo path after deployment.

- [ ] Decide what to do with the Vaultwarden admin panel.
  - [ ] Disable `ADMIN_PANEL_ENABLED` if it is not actively needed.
  - [ ] If keeping it enabled, restrict `/admin` in Caddy with IP allowlisting or extra auth.
  - [ ] Confirm `ADMIN_TOKEN` is stored only in `/var/lib/vaultwarden/vaultwarden.env`.
  - [ ] Confirm `ADMIN_TOKEN` is an Argon2 hash, not a plain token.

- [ ] Harden the `rebuild` script.
  - [ ] Change `set -e` to `set -euo pipefail`.
  - [ ] Validate `TARGET_HOST` against known hosts or a strict hostname regex.
  - [ ] Check that `nh`, `git`, `grep`, and `awk` are available before doing work.
  - [ ] Fail clearly if `nh os switch` or `nh os boot` fails.
  - [ ] Parse the current generation robustly and fail if it cannot be determined.
  - [ ] Do not treat every `git commit` failure as "No changes to commit".
  - [ ] Consider refusing `./rebuild nixvps` unless running on `nixvps`.

- [ ] Expand `.gitignore` to reduce accidental secret commits.
  - [ ] Ignore `.env`, `.env.*`, `*.key`, `*.pem`, `*.secret`, `*.pass`, `*.pw`.
  - [ ] Ignore `secrets/`, `private/`, and other local secret directories.
  - [ ] Explicitly ignore `vaultwarden.env`.
  - [ ] Ignore local OpenWeatherMap key files if they might ever be created inside the repo.

## P1 - High-value improvements

- [ ] Make the Caddy reverse proxy config more explicit.
  - [ ] Use `reverse_proxy 127.0.0.1:8222` instead of `localhost:8222`.
  - [ ] Add HSTS.
  - [ ] Add basic security headers: `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, and frame policy as appropriate for Vaultwarden.
  - [ ] Explicitly set trusted forwarded headers for Vaultwarden.
  - [ ] Verify Vaultwarden still sees correct client IPs after the header changes.

- [ ] Add SSH hardening on the VPS if the features are not needed.
  - [ ] Set `AllowAgentForwarding = false`.
  - [ ] Set `AllowTcpForwarding = false`.
  - [ ] Set `X11Forwarding = false`.
  - [ ] Set `PermitTunnel = "no"`.
  - [ ] Add `ClientAliveInterval` and `ClientAliveCountMax` if idle session cleanup is desired.

- [ ] Decide whether `nix.settings.trusted-users = [ "luke" ];` is necessary on the VPS.
  - [ ] Keep it only if trusted Nix operations as `luke` are required.
  - [ ] Document why it is needed if it stays.

- [ ] Make NUR follow the main nixpkgs input.
  - [ ] Update `flake.nix` so `nur.inputs.nixpkgs.follows = "nixpkgs";`.
  - [ ] Verify the flake still evaluates.

- [ ] Add project quality gates.
  - [ ] Add a Nix formatter via `formatter.x86_64-linux`.
  - [ ] Add or document a local check command for `nix flake check --no-build`.
  - [ ] Add ShellCheck coverage for `rebuild`.
  - [ ] Add Python formatting/linting for `hosts/nixnotdix/assets/weather/main.py`.
  - [ ] Consider GitHub Actions or another CI workflow for flake evaluation.

- [ ] Improve weather widget reliability.
  - [ ] Print a clear fallback value on API failure instead of printing nothing.
  - [ ] Exit non-zero on real weather lookup failure.
  - [ ] Use `requests.get(..., params=...)` instead of manually building query strings.
  - [ ] Replace generic `Mozilla/5.0` user agent with a descriptive widget user agent.
  - [ ] Use a proper `Retry` strategy with backoff instead of bare `HTTPAdapter(max_retries=5)`.

- [ ] Revisit Sway config validation.
  - [ ] Try enabling `checkConfig = true;`.
  - [ ] If validation must stay disabled, add a comment explaining the exact reason.

## P2 - Maintainability cleanup

- [ ] Move Waybar weather files to Home Manager `xdg.configFile`.
  - [ ] Replace absolute `home.file."${weatherDir}/..."` paths where practical.
  - [ ] Keep the API key file outside the Nix store and outside git.

- [ ] Centralize repeated desktop constants.
  - [ ] Put monitor names, workspace mappings, weather location, VPS SSH port, and similar host constants in one obvious place.
  - [ ] Keep host-specific values out of shared modules.

- [ ] Improve Bash prompt compatibility.
  - [ ] Avoid fully overwriting `PROMPT_COMMAND`.
  - [ ] Compose with any existing prompt command so integrations like direnv can coexist cleanly.

- [ ] Document intentionally pinned state versions.
  - [ ] Add a comment near `system.stateVersion = "25.11";` for `nixnotdix`.
  - [ ] Add a comment near `home.stateVersion = "25.11";`.
  - [ ] Do not bump these just because nixpkgs is pinned to 26.05.

- [ ] Replace the raw VPS IP in SSH config with DNS if available.
  - [ ] Prefer a stable hostname over `66.228.49.38`.
  - [ ] Keep the custom SSH port if desired.

- [ ] Document or isolate the BattlEye host blocking.
  - [ ] Add a clear comment explaining why those domains are mapped to `0.0.0.0`.
  - [ ] Consider moving them to a clearly named local policy module.

- [ ] Trim production VPS packages.
  - [ ] Decide whether `claude-code` and `github-copilot-cli` belong on a Vaultwarden VPS.
  - [ ] Move rarely used diagnostic/dev tools to `nix shell` if they do not need to be permanently installed.
  - [ ] Keep only tools that are needed for routine server administration.

- [ ] Improve Clone Hero overlay maintenance.
  - [ ] Consolidate version strings so the custom version is not repeated in multiple places.
  - [ ] Document when the local package override can be removed.
  - [ ] Keep the overlay logic simple and predictable when nixpkgs catches up.

- [ ] Consolidate repeated theme/color helper logic.
  - [ ] Add helper functions in `theme.nix` or a small companion module for hex stripping / ANSI conversion.
  - [ ] Use those helpers from Sway, Fuzzel, and Bash config.

- [ ] Improve README operational docs.
  - [ ] Add backup and restore procedure.
  - [ ] Add secret recovery procedure for `/var/lib/vaultwarden/vaultwarden.env`.
  - [ ] Add update cadence notes for `nix flake update`.
  - [ ] Note that Luke should run `./rebuild` locally and not from agents.

## P3 - Nice to have

- [ ] Add fail2ban observability.
  - [ ] Explicitly confirm the SSH jail is enabled.
  - [ ] Consider email notifications for bans.
  - [ ] Consider Vaultwarden/Caddy-specific filters if logs expose useful failed-login patterns.

- [ ] Add SSH key metadata.
  - [ ] Record the fingerprint for `keys/luke.pub` in a nearby comment or docs.
  - [ ] Verify the key type is modern, preferably Ed25519.

- [ ] Review GRUB serial console exposure on `nixvps`.
  - [ ] Decide whether Linode serial console access is acceptable as-is.
  - [ ] Consider a GRUB password only if it does not make VPS recovery painful.

- [ ] Improve Python weather script polish.
  - [ ] Add a short module docstring.
  - [ ] Add function docstrings only where they clarify behavior.
  - [ ] Avoid IP geolocation fallback unless it is actually useful.
  - [ ] If IP geolocation stays, make wrong-location fallback obvious.

- [ ] Reduce README / `CLAUDE.md` drift.
  - [ ] Decide which file is the source of truth.
  - [ ] Keep `CLAUDE.md` focused on agent instructions and link to README for human docs.

- [ ] Consider local pre-commit checks.
  - [ ] Format Nix files.
  - [ ] Run ShellCheck on shell scripts.
  - [ ] Compile or lint Python scripts.
  - [ ] Run `nix flake check --no-build`.

## Verification checklist for future changes

- [ ] `nix flake check --no-build --no-write-lock-file`
- [ ] Instantiate both system toplevel derivations without building.
- [ ] Confirm `nixvps` services start: Vaultwarden, Caddy, OpenSSH, fail2ban.
- [ ] Confirm Vaultwarden login works after Caddy/header/admin-panel changes.
- [ ] Confirm Vaultwarden email invite/password-reset delivery works.
- [ ] Confirm latest backup exists and can be decrypted.
- [ ] Confirm a test restore works before trusting the backup system.
- [ ] Confirm Sway starts and keybindings still work after desktop config changes.
- [ ] Confirm Waybar weather shows a sensible fallback when the API key/network is unavailable.


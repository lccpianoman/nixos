set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

rebuild *args:
  ./rebuild {{args}}

boot *args:
  ./rebuild --boot {{args}}

check:
  nix flake check --no-build --no-write-lock-file

garbage:
  nix-collect-garbage -d
  sudo nix-collect-garbage -d

optimize:
  nix store optimise
  sudo nix store optimise

# Point git at the tracked hooks; run once per clone.
hooks:
  git config core.hooksPath .githooks

# Same check the pre-commit hook runs, over every file already in secrets/.
check-secrets:
  #!/usr/bin/env bash
  set -euo pipefail
  shopt -s nullglob globstar
  fail=0
  for f in secrets/**/*; do
    [[ -f $f ]] || continue
    if [[ $(sops filestatus "$f" 2>/dev/null) == *'"encrypted":true'* ]]; then
      printf 'ok         %s\n' "$f"
    else
      printf 'PLAINTEXT  %s\n' "$f"
      fail=1
    fi
  done
  exit $fail

shellcheck:
  nix run nixpkgs#shellcheck -- ./rebuild

fmt:
  nix fmt

minecraft host='nixcraft' server='survival':
  @echo "Attaching to Minecraft console '{{server}}' on {{host}}..."
  @echo "Detach safely with Ctrl-b then d (do NOT run 'stop' unless you mean to stop the server)."
  @sleep 3
  ssh -t {{host}} "if [ -S /run/minecraft/{{server}}.sock ]; then tmux -S /run/minecraft/{{server}}.sock attach; else echo 'No console socket at /run/minecraft/{{server}}.sock (is minecraft-server-{{server}} running?)'; exit 1; fi"

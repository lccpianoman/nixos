set shell := ["bash", "-euo", "pipefail", "-c"]

default:
  @just --list

rebuild *args:
  ./rebuild {{args}}

boot *args:
  ./rebuild --boot {{args}}

check:
  nix flake check --no-build --no-write-lock-file

shellcheck:
  nix run nixpkgs#shellcheck -- ./rebuild

fmt:
  nix fmt

minecraft host='nixcraft' server='survival':
  @echo "Attaching to Minecraft console '{{server}}' on {{host}}..."
  @echo "Detach safely with Ctrl-b then d (do NOT run 'stop' unless you mean to stop the server)."
  @sleep 3
  ssh -t {{host}} "if [ -S /run/minecraft/{{server}}.sock ]; then tmux -S /run/minecraft/{{server}}.sock attach; else echo 'No console socket at /run/minecraft/{{server}}.sock (is minecraft-server-{{server}} running?)'; exit 1; fi"

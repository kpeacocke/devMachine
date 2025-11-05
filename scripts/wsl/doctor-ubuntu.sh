#!/usr/bin/env bash
set -euo pipefail

ok(){ printf "\e[32m[✓]\e[0m %s\n" "$*"; }
bad(){ printf "\e[31m[✗]\e[0m %s\n" "$*"; }
inf(){ printf "\e[36m[i]\e[0m %s\n" "$*"; }

inf "Surface Dev Doctor — Ubuntu (WSL)"

need() { command -v "$1" >/dev/null 2>&1; }

for c in gcc g++ make cmake pkg-config; do
  if need "$c"; then ok "$c found"; else bad "$c missing"; fi
done

if need R; then
  ok "R found"
  R -q -e "library(languageserver);library(lintr);library(styler)" >/dev/null 2>&1 && ok "R packages: languageserver/lintr/styler" || bad "R packages missing"
else bad "R missing"; fi

if need php; then ok "PHP found"; else bad "PHP missing"; fi
if need composer; then
  ok "Composer found"
  PATHS="$HOME/.config/composer/vendor/bin"
  [[ ":$PATH:" == *":$PATHS:"* ]] && ok "Composer global bin on PATH" || bad "Composer global bin NOT on PATH"
  for t in phpcs phpstan psalm php-cs-fixer; do
    if command -v "$t" >/dev/null 2>&1; then ok "$t found"; else bad "$t missing"; fi
  done
else bad "Composer missing"; fi

if need ruby; then ok "Ruby found"; else bad "Ruby missing"; fi
for g in bundler rubocop; do
  if need "$g"; then ok "$g found"; else bad "$g missing"; fi
done

if need node && need npm; then ok "Node & npm found"; else bad "Node/npm missing"; fi
for n in eslint prettier markdownlint stylelint tsc; do
  if need "$n"; then ok "$n found"; else bad "$n missing"; fi
done

if need docker; then
  if docker info >/dev/null 2>&1; then ok "Docker CLI works (WSL integration)"; else bad "Docker CLI cannot reach daemon — enable WSL integration in Docker Desktop"; fi
else bad "docker missing"; fi

if need tflint; then ok "tflint found"; else bad "tflint missing"; fi

for l in shellcheck; do
  if need "$l"; then ok "$l found"; else bad "$l missing"; fi
done

echo
ok "Doctor check finished"

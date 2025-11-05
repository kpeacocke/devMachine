#!/usr/bin/env bash
set -e
for c in git node npm java javac kotlin gradle sbt python3 pip3 shellcheck; do
  command -v "$c" >/dev/null || { echo "MISSING: $c"; exit 1; }
done
echo "OK"

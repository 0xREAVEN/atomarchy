#!/bin/bash
# Atomarchy build entry point, run by the Containerfile:
#
#   build.sh common   Omarchy 4 on ghcr.io/ublue-os/base-main  -> atomarchy
#   build.sh gaming   Bazzite kernel + gaming stack on top      -> atomarchy-gaming
#
# Each stage runs build_files/<stage>/*.sh in lexical order, all sourcing
# lib.sh. Steps are small and single-purpose so a failure points at one file.
set -euo pipefail

stage=${1:?usage: build.sh <common|gaming>}
here=$(cd "$(dirname "$0")" && pwd)
export CTX=${CTX:-$(dirname "$here")}

# shellcheck source=build_files/lib.sh
source "$here/lib.sh"

[[ -d $here/$stage ]] || die "unknown stage: $stage"

for step in "$here/$stage"/*.sh; do
  log "[$stage] ${step##*/}"
  # shellcheck source=/dev/null
  source "$step"
done

log "[$stage] done: $(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' omarchy hyprland quickshell kernel | tr '\n' ' ')"

# shellcheck shell=bash
# Shared helpers for the atomic (bootc / rpm-ostree) versions of omarchy-*
# commands. Sourced, not executed.

atomic_note() {
  printf '\e[33m%s\e[0m\n' "$*" >&2
}

atomic_as_root() {
  if (( EUID == 0 )); then
    "$@"
  else
    sudo "$@"
  fi
}

# JSON for the booted deployment.
atomic_booted_json() {
  rpm-ostree status --json 2>/dev/null | jq -c '.deployments[] | select(.booted == true)'
}

# Packages layered on top of the image (one per line).
atomic_layered_packages() {
  atomic_booted_json | jq -r '(.["requested-packages"] // [])[], (.["requested-local-packages"] // [])[]' 2>/dev/null
}

# True when an upgrade/rebase/layering change waits for the next boot.
atomic_has_staged_deployment() {
  rpm-ostree status --json 2>/dev/null | jq -e '[.deployments[] | select(.staged == true)] | length > 0' >/dev/null
}

# Tell Omarchy's update flow (omarchy-update-restart) a reboot is needed.
atomic_mark_reboot_required() {
  if (( EUID != 0 )); then
    mkdir -p "$HOME/.local/state/omarchy"
    touch "$HOME/.local/state/omarchy/reboot-required"
  fi
}

atomic_brew() {
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    /home/linuxbrew/.linuxbrew/bin/brew "$@"
  else
    return 127
  fi
}

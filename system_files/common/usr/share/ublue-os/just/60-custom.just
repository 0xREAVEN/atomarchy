# vim: set ft=make :
# Atomarchy recipes, imported by Universal Blue's justfile (ujust).

import? "/usr/share/ublue-os/just/61-atomarchy-gaming.just"

# Show Atomarchy, Omarchy and image versions
[group("atomarchy")]
atomarchy-info:
    #!/usr/bin/bash
    jq . /usr/share/ublue-os/image-info.json
    rpm -q omarchy omarchy-settings hyprland quickshell uwsm kernel
    rpm-ostree status --booted

# Read-only health check: image, signature policy, session, services
[group("atomarchy")]
atomarchy-doctor:
    /usr/libexec/atomarchy/doctor

# Switch update channel: stable (default) or testing
[group("atomarchy")]
atomarchy-channel channel="":
    #!/usr/bin/bash
    set -euo pipefail
    info=/usr/share/ublue-os/image-info.json
    ref=$(jq -r '."image-ref"' "$info")
    current=$(jq -r '."image-tag"' "$info")
    channel="{{ channel }}"
    if [[ -z $channel ]]; then
      echo "Current channel: $current"
      channel=$(gum choose stable testing)
    fi
    case "$channel" in
      stable|testing) ;;
      *) echo "Unknown channel: $channel (stable or testing)"; exit 1 ;;
    esac
    image=${ref#ostree-image-signed:docker://}
    image=${image#ostree-unverified-registry:}
    echo "Switching to ${image}:${channel}"
    if [[ $ref == ostree-image-signed:* ]]; then
      # Refuse an image that is not signed with the project key.
      sudo bootc switch --enforce-container-sigpolicy "${image}:${channel}"
    else
      sudo bootc switch "${image}:${channel}"
    fi
    echo "Reboot to use the ${channel} channel."

# Seed Omarchy configs into your home (safe: keeps your existing files)
[group("atomarchy")]
atomarchy-setup:
    #!/usr/bin/bash
    /usr/libexec/atomarchy/user-init
    state="${XDG_STATE_HOME:-$HOME/.local/state}/atomarchy"
    if compgen -G "$state/skipped-*.txt" >/dev/null; then
      echo "Kept as they were (see ujust atomarchy-reset-configs):"
      cat "$state"/skipped-*.txt | sort -u | tail -n 50
    fi

# Replace your configs with Omarchy's defaults (old files are backed up)
[group("atomarchy")]
atomarchy-reset-configs:
    #!/usr/bin/bash
    gum confirm "Replace conflicting configs with Omarchy defaults (backup kept)?" || exit 0
    /usr/libexec/atomarchy/user-init --reset

# Allow your user to use Docker without sudo (security: docker group = root)
[group("atomarchy")]
atomarchy-docker-group:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Membership of the docker group is equivalent to root access."
    gum confirm "Add $USER to the docker group?" || exit 0
    # On ostree, groups created by packages live in /usr/lib/group only.
    if ! grep -q '^docker:' /etc/group; then
      grep '^docker:' /usr/lib/group | sudo tee -a /etc/group >/dev/null
    fi
    sudo usermod -aG docker "$USER"
    echo "Log out and back in to apply."

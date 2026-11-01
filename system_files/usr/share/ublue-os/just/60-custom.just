# vim: set ft=make :
# Omarchy recipes for bazzite-omarchy (imported by Bazzite's justfile).

# Show Omarchy and image versions
[group("omarchy")]
omarchy-info:
    #!/usr/bin/bash
    rpm -q omarchy omarchy-settings hyprland quickshell uwsm
    jq . /usr/share/ublue-os/image-info.json
    rpm-ostree status --booted

# Seed Omarchy configs into your home (safe: keeps your existing files)
[group("omarchy")]
omarchy-setup:
    /usr/libexec/omarchy-atomic/user-init && cat "${XDG_STATE_HOME:-$HOME/.local/state}"/omarchy-atomic/skipped-*.txt 2>/dev/null | tail -n 50 || true

# Replace your configs with Omarchy's defaults (old files are backed up)
[group("omarchy")]
omarchy-reset-configs:
    #!/usr/bin/bash
    gum confirm "Replace conflicting configs with Omarchy defaults (backup kept)?" || exit 0
    /usr/libexec/omarchy-atomic/user-init --reset

# Allow your user to use Docker without sudo (security: docker group = root)
[group("omarchy")]
omarchy-docker-group:
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

# Use Omarchy's Plymouth boot splash (rebuilds the initramfs locally)
[group("omarchy")]
omarchy-plymouth:
    #!/usr/bin/bash
    set -euo pipefail
    echo "This enables a local initramfs (rpm-ostree initramfs --enable) with the Omarchy theme."
    gum confirm "Continue?" || exit 0
    sudo mkdir -p /etc/plymouth
    printf '[Daemon]\nTheme=omarchy\n' | sudo tee /etc/plymouth/plymouthd.conf >/dev/null
    sudo rpm-ostree initramfs --enable --arg=--add=plymouth
    sudo rpm-ostree initramfs-etc --track=/etc/plymouth/plymouthd.conf
    echo "Reboot to see it. Undo with: sudo rpm-ostree initramfs --disable"

# Install Omarchy's default Flatpak apps now (normally done at boot)
[group("omarchy")]
omarchy-flatpaks:
    sudo systemctl start omarchy-atomic-flatpaks.service && journalctl -b -u omarchy-atomic-flatpaks.service --no-pager | tail -n 20

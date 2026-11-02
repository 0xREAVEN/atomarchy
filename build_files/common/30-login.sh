# shellcheck shell=bash
# Login screen and boot splash, as on Omarchy: SDDM with the Omarchy theme and
# its Hyprland-based greeter, and the Omarchy Plymouth theme.

# omarchy-settings ships the SDDM theme, the greeter compositor config and the
# sddm.conf.d drop-ins; fail loudly if a future Omadora release moves them.
for path in \
  /usr/share/sddm/themes/omarchy/Main.qml \
  /usr/share/sddm/hyprland.lua \
  /etc/sddm.conf.d/10-theme.conf \
  /etc/sddm.conf.d/10-wayland.conf \
  /usr/share/plymouth/themes/omarchy/omarchy.plymouth; do
  [[ -e $path ]] || die "missing $path (omarchy-settings layout changed?)"
done

systemctl enable sddm.service
systemctl set-default graphical.target

# Plymouth: the theme is baked into the initramfs (rebuilt in 80-initramfs.sh).
plymouth-set-default-theme omarchy

# The splash needs "rhgb quiet" on the kernel command line. bootc applies
# kargs.d on installation and keeps them in sync on upgrades.
mkdir -p /usr/lib/bootc/kargs.d
cat >/usr/lib/bootc/kargs.d/10-atomarchy-splash.toml <<'EOF'
kargs = ["rhgb", "quiet"]
EOF

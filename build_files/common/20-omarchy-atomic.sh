# shellcheck shell=bash
# Adapt Omadora's Omarchy (written for a mutable Fedora: dnf, Limine,
# Snapper) to a bootc image.

install_tree common
chmod 0755 /usr/libexec/atomarchy/session /usr/libexec/atomarchy/user-init /usr/libexec/atomarchy/doctor /usr/share/atomarchy/bin/*

# --- Commands that change packages, the bootloader or snapshots ------------
# Replaced by rpm-ostree / bootc / Flatpak versions. The Omadora originals
# are kept in /usr/share/atomarchy/orig for reference.
mkdir -p /usr/share/atomarchy/orig
for override in /usr/share/atomarchy/bin/*; do
  name=${override##*/}
  if [[ -e /usr/bin/$name && ! -L /usr/bin/$name ]]; then
    cp -a "/usr/bin/$name" "/usr/share/atomarchy/orig/$name"
  fi
  install -m 0755 "$override" "/usr/bin/$name"
  # $OMARCHY_PATH/bin holds symlinks to /usr/bin; make sure ours exists too.
  ln -sfn "/usr/bin/$name" "/usr/share/omarchy/bin/$name"
done

# One-line dnf calls inside otherwise portable commands.
sed -i 's/sudo dnf remove -y \$quoted_package/omarchy-pkg-drop $quoted_package/' /usr/bin/omarchy-remove-launcher-entry
sed -i 's|sudo dnf install -y "https://github.com/symfony-cli|sudo rpm-ostree install --apply-live -y "https://github.com/symfony-cli|' /usr/bin/omarchy-install-dev-env
sed -i 's|sudo dnf install -y https://repo.nordvpn.com|sudo rpm-ostree install --apply-live -y https://repo.nordvpn.com|' /usr/bin/omarchy-install-service-nordvpn

# Anything still calling dnf directly would fail on the read-only /usr.
# omarchy-dev-pkg-test is a developer tool for building Omarchy RPMs.
leftovers=$(grep -lE '(sudo |^\s*)dnf5? (install|remove|upgrade|distro-sync|autoremove)' /usr/bin/omarchy-* |
  grep -vx '/usr/bin/omarchy-dev-pkg-test' || true)
[[ -z $leftovers ]] || die "omarchy commands still calling dnf directly: $leftovers"

# --- Chromium naming --------------------------------------------------------
# Omarchy names Chromium "chromium" / chromium.desktop (default browser,
# mimeapps, every web app). Fedora ships chromium-browser(.desktop).
if [[ -x /usr/bin/chromium-browser && ! -e /usr/bin/chromium ]]; then
  ln -s chromium-browser /usr/bin/chromium
fi
apps=/usr/share/applications
if [[ -f $apps/chromium-browser.desktop && ! -e $apps/chromium.desktop ]]; then
  cp "$apps/chromium-browser.desktop" "$apps/chromium.desktop"
  # Keep a single Chromium entry in launchers.
  sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$apps/chromium-browser.desktop"
fi

# sysusers.d belongs in /usr on bootc (/etc is per-machine state).
if [[ -f /etc/sysusers.d/omarchy-cups-browsed.conf ]]; then
  install -Dm0644 /etc/sysusers.d/omarchy-cups-browsed.conf /usr/lib/sysusers.d/omarchy-cups-browsed.conf
  rm -f /etc/sysusers.d/omarchy-cups-browsed.conf
fi

# --- Leftovers of the Arch / mutable-Fedora boot story ----------------------
rm -rf /etc/limine-entry-tool.d /etc/mkinitcpio.conf.d
rm -f /etc/snapper/config-templates/omarchy

# fcitx5 is not part of the images; without it these variables only make
# toolkits look for an input method that is not there.
rm -f /usr/lib/environment.d/10-omarchy-fcitx.conf

# --- Session ---------------------------------------------------------------
# Plain "Hyprland" sessions would start Hyprland without seeding the user's
# Omarchy config; the login screen offers the Omarchy session only.
for session in /usr/share/wayland-sessions/hyprland*.desktop; do
  [[ -f $session ]] || continue
  grep -q '^NoDisplay=' "$session" || echo 'NoDisplay=true' >>"$session"
  grep -q '^Hidden=' "$session" || echo 'Hidden=true' >>"$session"
done
# Omadora's session file is replaced by ours (seeds $HOME, then uwsm).
install -m 0644 "$FILES/common/usr/share/wayland-sessions/omarchy.desktop" /usr/share/wayland-sessions/omarchy.desktop
rm -f /usr/local/share/wayland-sessions/omarchy.desktop

#!/bin/bash
# Layers Omarchy 4 (via the Omadora Fedora RPMs) on top of a Bazzite image.
# Runs once, inside the Containerfile build, as root.
set -euo pipefail

CTX=/ctx
FILES=$CTX/system_files
ATOMIC_SHARE=/usr/share/omarchy-atomic

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }

read_list() { grep -vE '^\s*(#|$)' "$1"; }

# ---------------------------------------------------------------------------
log "Repositories"
# Omadora: omarchy, omarchy-settings and the Omarchy first-party apps.
# lionheartp/Hyprland: the Hyprland 0.57 stack, Quickshell and uwsm that
# Omarchy 4 requires (Lua config, Quickshell desktop).
dnf5 -y copr enable kammer/omadora
dnf5 -y copr enable lionheartp/Hyprland
# Bazzite tunes its own repos with priorities (terra=1, bazzite=2, COPRs=98).
# Keep these two at the bottom so they can never replace a Bazzite package
# that also exists in a higher-priority repo.
dnf5 -y config-manager setopt \
  "copr:copr.fedorainfracloud.org:kammer:omadora.priority=99" \
  "copr:copr.fedorainfracloud.org:lionheartp:Hyprland.priority=99"

# ---------------------------------------------------------------------------
log "Xwayland compatibility"
# Bazzite swaps Fedora's Xwayland for terra-xorg-x11-server-Xwayland, which
# provides "xorg-x11-server-Xwayland" but not the arch-qualified
# "xorg-x11-server-Xwayland(x86-64)" that every Fedora Hyprland spec requires.
# A file-less package adds that provide so Bazzite's newer Xwayland is kept.
if xw_version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' terra-xorg-x11-server-Xwayland 2>/dev/null); then
  dnf5 -y install rpm-build
  topdir=$(mktemp -d)
  mkdir -p "$topdir/SPECS"
  cat >"$topdir/SPECS/xwayland-compat.spec" <<EOF
%global debug_package %{nil}
Name:      omarchy-atomic-xwayland-compat
Version:   1
Release:   1
Summary:   Arch-qualified Xwayland provide for Bazzite's terra Xwayland
License:   MIT
Requires:  terra-xorg-x11-server-Xwayland = ${xw_version}
Provides:  xorg-x11-server-Xwayland%{?_isa} = ${xw_version}
%description
Lets Fedora-built Hyprland packages depend on Bazzite's Xwayland.
%files
EOF
  rpmbuild --define "_topdir $topdir" -bb "$topdir/SPECS/xwayland-compat.spec" >/dev/null
  rpm -Uvh --replacepkgs "$topdir"/RPMS/*/omarchy-atomic-xwayland-compat-*.rpm
  rm -rf "$topdir"
  dnf5 -y remove rpm-build
fi

# ---------------------------------------------------------------------------
log "Packages"
mapfile -t packages < <(read_list "$CTX/build_files/packages.txt")

# util-linux-script must match Bazzite's util-linux exactly; unpinned, dnf
# would upgrade util-linux and its libraries under Bazzite.
ul_version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' util-linux)
packages=("${packages[@]/#util-linux-script/util-linux-script-$ul_version}")

if [[ $WITH_FCITX == 1 ]]; then
  packages+=(fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool
    fcitx5-chinese-addons fcitx5-hangul fcitx5-mozc fcitx5-chewing fcitx5-table-extra)
fi

if [[ $WITH_DOCKER == 1 ]]; then
  packages+=(moby-engine docker-cli docker-buildx docker-compose)
fi

# omarchy-settings' %posttrans runs omarchy-sudo-passwordless, which takes a
# lock in /run/lock and checks /run is root-owned 0755, as on a booted system.
# Container builds start with a bare /run tmpfs (not part of the image).
mkdir -p /run/lock
chmod 0755 /run
chmod 0755 /run/lock

# omarchy-settings' %post copies its plymouthd.conf over Bazzite's; keep a copy.
saved_plymouth=$(mktemp)
cp -a /etc/plymouth/plymouthd.conf "$saved_plymouth" 2>/dev/null || true

# Terra ships with Bazzite but is disabled after its build; enable it for this
# transaction only (mise, usage-cli, starship, lazygit).
dnf5 -y install --enable-repo=terra "${packages[@]}"

# Omarchy drives power profiles through powerprofilesctl. Bazzite uses
# tuned-ppd, which implements the same D-Bus API but ships no CLI, and
# power-profiles-daemon conflicts with it. Take only the client script.
log "powerprofilesctl client for tuned-ppd"
if ! command -v powerprofilesctl >/dev/null; then
  ppd_dir=$(mktemp -d)
  dnf5 -y download --destdir "$ppd_dir" power-profiles-daemon
  (cd "$ppd_dir" && rpm2cpio ./*.rpm | cpio -idm --quiet ./usr/bin/powerprofilesctl)
  install -m 0755 "$ppd_dir/usr/bin/powerprofilesctl" /usr/bin/powerprofilesctl
  rm -rf "$ppd_dir"
fi

# ---------------------------------------------------------------------------
log "System files"
cp -a "$FILES/." /
chmod 0755 /usr/libexec/omarchy-atomic/* "$ATOMIC_SHARE"/bin/*

# ---------------------------------------------------------------------------
log "Atomic overrides for package / boot commands"
# Omadora's omarchy-* commands assume a mutable Fedora (dnf, Limine, Snapper).
# On bootc the root is read-only, so the commands that change packages, the
# bootloader or snapshots are replaced by versions built on rpm-ostree,
# bootc and Flatpak. Originals are kept for reference.
mkdir -p "$ATOMIC_SHARE/orig"
for override in "$ATOMIC_SHARE"/bin/*; do
  name=${override##*/}
  if [[ -e /usr/bin/$name && ! -L /usr/bin/$name ]]; then
    cp -a "/usr/bin/$name" "$ATOMIC_SHARE/orig/$name"
  fi
  install -m 0755 "$override" "/usr/bin/$name"
  # $OMARCHY_PATH/bin holds symlinks to /usr/bin; make sure ours exists too.
  ln -sfn "/usr/bin/$name" "/usr/share/omarchy/bin/$name"
done

# One-line dnf calls inside otherwise portable commands.
sed -i 's/sudo dnf remove -y \$quoted_package/omarchy-pkg-drop $quoted_package/' /usr/bin/omarchy-remove-launcher-entry
sed -i 's|sudo dnf install -y "https://github.com/symfony-cli|sudo rpm-ostree install --apply-live -y "https://github.com/symfony-cli|' /usr/bin/omarchy-install-dev-env
sed -i 's|sudo dnf install -y https://repo.nordvpn.com|sudo rpm-ostree install --apply-live -y https://repo.nordvpn.com|' /usr/bin/omarchy-install-service-nordvpn

# Report any remaining direct dnf transaction in Omarchy commands.
if leftovers=$(grep -lE '(sudo |^\s*)dnf5? (install|remove|upgrade|distro-sync|autoremove)' /usr/bin/omarchy-* 2>/dev/null); then
  echo "Commands still calling dnf directly (will fail on a read-only /usr):"
  printf '  %s\n' $leftovers
fi

# Omarchy (and Omadora) name Chromium "chromium" / chromium.desktop: default
# browser, mimeapps and every web app launcher. Fedora ships
# /usr/bin/chromium-browser and chromium-browser.desktop, so without these
# aliases web apps and `xdg-settings set default-web-browser` fail.
if [[ -x /usr/bin/chromium-browser && ! -e /usr/bin/chromium ]]; then
  ln -s chromium-browser /usr/bin/chromium
fi
apps=/usr/share/applications
if [[ -f $apps/chromium-browser.desktop && ! -e $apps/chromium.desktop ]]; then
  cp "$apps/chromium-browser.desktop" "$apps/chromium.desktop"
  # Keep a single Chromium entry in launchers.
  sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$apps/chromium-browser.desktop"
fi

# ---------------------------------------------------------------------------
log "Reconcile Omarchy defaults with Bazzite"
# Bazzite already tunes memory, I/O and zram for gaming; keep its values.
rm -f /usr/lib/systemd/zram-generator.conf.d/90-omarchy.conf
rm -f /etc/sysctl.d/99-omarchy-sysctl.conf
rm -f /etc/udev/rules.d/60-omarchy-io-scheduler.rules
rm -f /etc/tmpfiles.d/omarchy-zswap.conf

# Arch / mutable-Fedora boot leftovers: no Limine, mkinitcpio or Snapper here.
rm -rf /etc/limine-entry-tool.d /etc/mkinitcpio.conf.d
rm -f /etc/snapper/config-templates/omarchy

# Bazzite's KDE image uses Plasma Login Manager and the GNOME image uses GDM;
# SDDM is not installed, so its Omarchy drop-ins would do nothing.
rm -f /etc/sddm.conf.d/10-theme.conf /etc/sddm.conf.d/10-wayland.conf
rmdir /etc/sddm.conf.d 2>/dev/null || true

# Docker's DNS stub only makes sense with Docker installed.
if [[ $WITH_DOCKER != 1 ]]; then
  rm -f /etc/systemd/resolved.conf.d/20-docker-dns.conf
  rm -rf /etc/systemd/system/docker.service.d /etc/docker
fi

# The fcitx variables are global in Omarchy (one desktop per machine). Here
# they would also hit Plasma/GNOME, which run their own input methods, so they
# move into the uwsm environment of the Omarchy session only.
if [[ -f /usr/lib/environment.d/10-omarchy-fcitx.conf ]]; then
  if [[ $WITH_FCITX == 1 ]]; then
    sed -E 's/^([A-Z_]+)=(.*)$/export \1=\2/' /usr/lib/environment.d/10-omarchy-fcitx.conf \
      >/usr/share/uwsm/env.d/20-omarchy-fcitx
  fi
  rm -f /usr/lib/environment.d/10-omarchy-fcitx.conf
fi

# Plain "Hyprland" sessions would start Hyprland without Omarchy's config
# seeding; hide them so the login screen offers the Omarchy session only.
for session in /usr/share/wayland-sessions/hyprland*.desktop; do
  [[ -f $session ]] || continue
  grep -q '^NoDisplay=' "$session" || echo 'NoDisplay=true' >>"$session"
  grep -q '^Hidden=' "$session" || echo 'Hidden=true' >>"$session"
done
# Omadora installs its session under /usr/share/wayland-sessions/omarchy.desktop;
# ours (from system_files) replaces it so the session can seed $HOME first.
install -m 0644 "$FILES/usr/share/wayland-sessions/omarchy.desktop" /usr/share/wayland-sessions/omarchy.desktop
rm -f /usr/local/share/wayland-sessions/omarchy.desktop 2>/dev/null || true

# ---------------------------------------------------------------------------
if [[ $WITH_PLYMOUTH_THEME == 1 ]]; then
  log "Plymouth theme + initramfs"
  plymouth-set-default-theme omarchy
  kver=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -printf '%f\n' | sort -V | tail -1)
  /usr/bin/dracut --no-hostonly --kver "$kver" --reproducible --add ostree -f "/usr/lib/modules/$kver/initramfs.img"
  chmod 0600 "/usr/lib/modules/$kver/initramfs.img"
else
  # Keep Bazzite's boot splash (its initramfs is not rebuilt in this mode).
  if [[ -s $saved_plymouth ]]; then
    cp -f "$saved_plymouth" /etc/plymouth/plymouthd.conf
  fi
fi

# ---------------------------------------------------------------------------
log "Services"
systemctl enable omarchy-atomic-flatpaks.service
if [[ $WITH_DOCKER == 1 ]]; then
  systemctl enable docker.socket
fi

# ---------------------------------------------------------------------------
log "Image identity"
info=/usr/share/ublue-os/image-info.json
if [[ -f $info ]]; then
  if [[ $IMAGE_SIGNED == 1 ]]; then
    transport=ostree-image-signed:docker://
  else
    transport=ostree-unverified-registry:
  fi
  tmp=$(mktemp)
  jq --arg name "$IMAGE_NAME" --arg vendor "$IMAGE_VENDOR" \
    --arg ref "${transport}${IMAGE_REGISTRY}/${IMAGE_NAME}" \
    --arg omarchy "$(rpm -q --qf '%{VERSION}-%{RELEASE}' omarchy)" \
    '."image-name"=$name | ."image-vendor"=$vendor | ."image-ref"=$ref | ."omarchy-version"=$omarchy' \
    "$info" >"$tmp"
  install -m 0644 "$tmp" "$info"
  rm -f "$tmp"
fi

# ---------------------------------------------------------------------------
log "Cleanup"
# Keep the two COPRs enabled: omarchy-pkg-add layers packages with rpm-ostree,
# and Omarchy's "Install" menu needs the Omadora repository to resolve them.
dnf5 clean all
rm -rf /var/lib/dnf /var/log/dnf5.log* /var/tmp/* 2>/dev/null || true
# /var is per-machine state on bootc; content created by package scriptlets is
# recreated at boot (tmpfiles.d) instead of shipping in the image.
rm -rf /var/lib/plocate /var/cache/ldconfig/aux-cache
find /var/log -type f -delete 2>/dev/null || true
log "Done: $(rpm -q omarchy hyprland quickshell | tr '\n' ' ')"

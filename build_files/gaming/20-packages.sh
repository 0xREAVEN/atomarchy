# shellcheck shell=bash
# Gaming stack from Terra, the same sources Bazzite uses:
#   terra-mesa    Mesa (RADV/ACO, VA-API) in 64 and 32 bits
#   terra         Steam, umu-launcher, LACT
#   terra-extras  gamescope, MangoHud
# and tuned + tuned-ppd for power profiles, as on Bazzite.

terra=(--enable-repo=terra --enable-repo=terra-extras --enable-repo=terra-mesa)

# --- Mesa: move every installed Mesa package to terra-mesa ------------------
# Priority 1 makes terra-mesa win over Fedora for mesa-* only.
mesa=(--enable-repo=terra-mesa --setopt=terra-mesa.priority=1)
mapfile -t installed_mesa < <(rpm -qa --qf '%{NAME}.%{ARCH}\n' 'mesa-*' | sort -u)
dnf5 -y "${mesa[@]}" distro-sync "${installed_mesa[@]}"
# 32-bit drivers for Steam and Proton. (terra-mesa's mesa-va-drivers.i686 lags
# behind the 64-bit Mesa; 32-bit VA-API is not used by games.)
dnf5 -y "${mesa[@]}" install \
  mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 mesa-libGL.i686 mesa-libEGL.i686

# --- Games ------------------------------------------------------------------
mapfile -t packages < <(read_list "$PACKAGES/gaming.txt")
dnf5 -y "${terra[@]}" --setopt=terra-mesa.priority=1 --setopt=install_weak_deps=False \
  install "${packages[@]}"

# --- Power profiles: tuned-ppd instead of power-profiles-daemon -------------
dnf5 -y --setopt=install_weak_deps=False swap omarchy-power-profiles-daemon tuned-ppd
# No weak dependencies: they would pull kernel-tools built for the Fedora
# kernel, not the OGC kernel this image boots.
dnf5 -y --setopt=install_weak_deps=False install tuned
# Omarchy drives power profiles through powerprofilesctl. tuned-ppd implements
# the same D-Bus API but ships no client, and power-profiles-daemon conflicts
# with it: take only the client script from Fedora's power-profiles-daemon.
if ! command -v powerprofilesctl >/dev/null; then
  ppd_dir=$(mktemp -d)
  dnf5 -y download --destdir "$ppd_dir" power-profiles-daemon
  (cd "$ppd_dir" && rpm2cpio ./*.rpm | cpio -idm --quiet ./usr/bin/powerprofilesctl)
  install -m 0755 "$ppd_dir/usr/bin/powerprofilesctl" /usr/bin/powerprofilesctl
  rm -rf "$ppd_dir"
fi

# Every package built from the mesa source must come from terra-mesa, or 32-bit
# and 64-bit drivers could end up from different builds. (mesa-libGLU is a
# separate project and stays Fedora's.)
stray=$(dnf5 repoquery --installed --qf '%{name}.%{arch} %{from_repo} %{sourcerpm}\n' 'mesa-*' |
  awk '$3 ~ /^mesa-[0-9]/ && $2 != "terra-mesa"')
[[ -z $stray ]] || die "Mesa packages not from terra-mesa: $stray"

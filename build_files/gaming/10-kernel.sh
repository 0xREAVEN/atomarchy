# shellcheck shell=bash
# Bazzite's gaming kernel (OGC) and the extra kernel modules selected for
# Atomarchy Gaming, from Universal Blue's akmods images.
#
# Adapted from Bazzite's build_files/install-kernel-akmods
# (https://github.com/ublue-os/bazzite, Apache License 2.0).
#
# The Containerfile bind-mounts the akmods images:
#   /tmp/kernel-rpms        kernel RPMs            (akmods:<flavor>-<fedora>-<kernel>)
#   /tmp/rpms/{common,kmods}                       (same image)
#   /tmp/rpms/{extra,kmods-extra}                  (akmods-extra, same tag)

[[ -d /tmp/kernel-rpms ]] || die "akmods image not mounted on /tmp/kernel-rpms"

# Swapping kernels must not run the rpm-ostree and dracut kernel-install
# plugins inside the build: the initramfs is rebuilt once at the end.
hooks=/usr/lib/kernel/install.d
for plugin in "$hooks/05-rpmostree.install" "$hooks/50-dracut.install"; do
  mv "$plugin" "$plugin.bak"
  printf '%s\n' '#!/bin/sh' 'exit 0' >"$plugin"
  chmod +x "$plugin"
done

for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-tools-libs kernel-tools; do
  if rpm -q "$pkg" >/dev/null 2>&1; then
    rpm --erase --nodeps "$pkg"
  fi
done
rm -rf /usr/lib/modules

dnf5 -y install \
  /tmp/kernel-rpms/kernel-[0-9]*.rpm \
  /tmp/kernel-rpms/kernel-core-*.rpm \
  /tmp/kernel-rpms/kernel-modules-*.rpm
dnf5 versionlock add kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra

# Extra modules (signed with the Universal Blue key, like the kernel):
#   xone            Xbox wireless adapter / controllers
#   new-lg4ff       Logitech wheels        hid-fanatecff   Fanatec wheels
#   hid-tmff2       Thrustmaster T300/TX   t150-driver     Thrustmaster T150/TMX
#   ryzen_smu       Ryzen SMU access (monitoring/tuning tools)
#   zenergy         AMD Zen energy sensors
kmods=()
add_kmod() {
  local name=$1 found=0 rpm
  shift
  for rpm in "$@"; do
    [[ -f $rpm ]] || continue
    kmods+=("$rpm")
    found=1
  done
  (( found )) || die "kernel module $name not found in the akmods images"
}
add_kmod xone /tmp/rpms/{common,kmods}/*xone*.rpm
for name in new-lg4ff hid-fanatecff hid-tmff2 t150-driver ryzen_smu zenergy; do
  add_kmod "$name" /tmp/rpms/{extra,kmods-extra}/*"$name"*.rpm
done
dnf5 -y install "${kmods[@]}"

for plugin in "$hooks/05-rpmostree.install" "$hooks/50-dracut.install"; do
  mv -f "$plugin.bak" "$plugin"
done

# Load NTSYNC at boot (Wine/Proton synchronisation primitives), as Bazzite does.
echo ntsync >/usr/lib/modules-load.d/atomarchy-ntsync.conf

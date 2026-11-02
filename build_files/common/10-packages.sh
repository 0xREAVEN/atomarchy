# shellcheck shell=bash
# Omarchy 4 and the Atomarchy package set (packages/common.txt).

mapfile -t packages < <(read_list "$PACKAGES/common.txt")

# util-linux-script must match the base image's util-linux exactly; unpinned,
# dnf would upgrade util-linux and its libraries under base-main.
ul_version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' util-linux)
packages=("${packages[@]/#util-linux-script/util-linux-script-$ul_version}")

# omarchy-settings' %posttrans runs omarchy-sudo-passwordless, which takes a
# lock in /run/lock and checks that /run is root-owned 0755, as on a booted
# system. Container builds start with a bare /run tmpfs (not part of the image).
mkdir -p /run/lock
chmod 0755 /run /run/lock

# uupd comes from ublue-os/packages, as on Bazzite (Terra carries its own build).
dnf5 -y install \
  --enable-repo='terra' --enable-repo='terra-extras' \
  --setopt='terra.exclude=uupd' --setopt='terra-extras.exclude=uupd' \
  "${packages[@]}"

# shellcheck shell=bash
# Rebuild the initramfs so it carries the Omarchy Plymouth theme (shown at the
# LUKS passphrase prompt too). The gaming stage runs this again after
# swapping the kernel.

kver=$(image_kernel)
# /root links to /var/roothome, which only exists on a booted system; dracut
# needs the target to exist.
mkdir -p "$(realpath /root)"
/usr/bin/dracut --no-hostonly --kver "$kver" --reproducible --zstd \
  --add ostree --add plymouth -f "/usr/lib/modules/$kver/initramfs.img"
chmod 0600 "/usr/lib/modules/$kver/initramfs.img"

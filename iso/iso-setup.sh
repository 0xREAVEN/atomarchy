#!/bin/bash
# Configures the Fedora bootc image as an Anaconda installer environment.
# Called by iso/Containerfile. Steps follow osbuild's Anaconda installer
# recipe; the ones lorax normally performs are marked as such.
set -euo pipefail

: "${PAYLOAD_REF:?}" "${PRODUCT_NAME:?}" "${ISO_LABEL:?}" "${FEDORA_VERSION:?}"
: "${ENROLL_UBLUE_KEY:=0}"

# Only the gaming image needs the Universal Blue Secure Boot key enrolled.
if [[ $ENROLL_UBLUE_KEY != 1 ]]; then
  rm -f /usr/share/atomarchy/akmods-ublue.der
fi

# --- ISO boot menu (read by image-builder) -----------------------------------
mkdir -p /usr/lib/image-builder/bootc
cat >/usr/lib/image-builder/bootc/iso.yaml <<EOF
label: "${ISO_LABEL}"
grub2:
  timeout: 10
  entries:
    - name: "Install ${PRODUCT_NAME}"
      linux: \${kernelpath} \${root} inst.graphical quiet rhgb
      initrd: \${initrdpath}
    - name: "Install ${PRODUCT_NAME} (basic graphics mode)"
      linux: \${kernelpath} \${root} inst.graphical nomodeset
      initrd: \${initrdpath}
EOF

# --- What Anaconda installs ----------------------------------------------------
# The payload is embedded in the ISO's container storage: offline install.
# The installed system then follows ${PAYLOAD_REF} for updates; the image's
# containers policy requires the project signature for it.
cat >/usr/share/anaconda/interactive-defaults.ks <<EOF
bootc --source-imgref containers-storage:${PAYLOAD_REF} --target-imgref ${PAYLOAD_REF}

%post --nochroot
# The gaming kernel and its modules are signed with the Universal Blue key.
# With Secure Boot on, queue it for enrollment: MokManager asks at next boot
# (password: universalblue), exactly as on Bazzite.
if [ -f /usr/share/atomarchy/akmods-ublue.der ] && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
  mokutil --timeout -1 || :
  printf 'universalblue\nuniversalblue\n' | mokutil --import /usr/share/atomarchy/akmods-ublue.der || :
fi
%end
EOF

# Product name shown by Anaconda (lorax writes this file).
cat >/.buildstamp <<EOF
[Main]
Product=${PRODUCT_NAME}
Version=${FEDORA_VERSION}
IsFinal=True
UUID=$(date -u +%Y%m%d%H%M).x86_64
Variant=${PRODUCT_NAME}

[Compose]
Lorax=none
EOF

# --- Normally done by lorax ------------------------------------------------------
echo "install:x:0:0:root:/root:/usr/libexec/anaconda/run-anaconda" >>/etc/passwd
echo "install::14438:0:99999:7:::" >>/etc/shadow
passwd -d root

mv /usr/share/anaconda/list-harddrives-stub /usr/bin/list-harddrives
# Hide the package repositories from Anaconda: it installs a container.
if [[ -d /usr/share/dnf5/repos.d ]]; then
  mv /usr/share/dnf5/repos.d /etc/anaconda.repos.d
else
  mv /etc/yum.repos.d /etc/anaconda.repos.d
fi
ln -sf /lib/systemd/system/anaconda.target /etc/systemd/system/default.target
rm -f /usr/lib/systemd/system-generators/systemd-gpt-auto-generator
ln -sf /usr/lib/systemd/system/anaconda-shell@.service /usr/lib/systemd/system/autovt@.service

mkdir -p /usr/lib/systemd/logind.conf.d
printf '[Login]\nReserveVT=2\n' >/usr/lib/systemd/logind.conf.d/anaconda-shell.conf

# Anaconda runs as root; let PipeWire start for it.
for unit in pipewire.service pipewire.socket; do
  mkdir -p "/etc/systemd/user/${unit}.d"
  printf '[Unit]\nConditionUser=\n' >"/etc/systemd/user/${unit}.d/allowroot.conf"
done

# Services that cannot work from the ISO.
systemctl mask bootloader-update.service 2>/dev/null || true

# Initramfs with the Anaconda dracut module.
mkdir -p "$(realpath /root)"
kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version')
DRACUT_NO_XATTR=1 dracut --force -v --zstd --reproducible --no-hostonly \
  --add "anaconda" "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

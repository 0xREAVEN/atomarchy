#!/bin/bash
# Boot test: install an Atomarchy image to a virtual disk with bootc, boot it
# in QEMU/KVM, and check the running system over SSH.
#
#   sudo tests/boot-test.sh <image> <workdir>
#
# <image> must be in root's container storage (sudo podman). Artifacts left in
# <workdir>: serial.log, journal.txt, checks.txt, screen.png (login screen).
# Needs: podman, qemu-system-x86_64, OVMF, /dev/kvm, ssh, socat.
set -euo pipefail

image=${1:?image}
work=${2:?workdir}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$work"
work=$(cd "$work" && pwd)

log() { printf '\n\033[1;34m--> %s\033[0m\n' "$*"; }

ovmf_code=$(ls /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/ovmf/OVMF_CODE.fd 2>/dev/null | head -1)
ovmf_vars=$(ls /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd /usr/share/edk2/ovmf/OVMF_VARS.fd 2>/dev/null | head -1)
[[ -n $ovmf_code && -n $ovmf_vars ]] || { echo "OVMF firmware not found" >&2; exit 2; }
[[ -c /dev/kvm ]] || { echo "/dev/kvm not available" >&2; exit 2; }

log "Installing $image to a virtual disk (bootc install to-disk)"
rm -f "$work/id" "$work/id.pub"
ssh-keygen -q -t ed25519 -N '' -f "$work/id"
truncate -s 40G "$work/disk.raw"
podman run --rm --privileged --pid=host \
  --security-opt label=type:unconfined_t \
  -v /dev:/dev -v /var/lib/containers:/var/lib/containers -v "$work:/output" \
  "$image" \
  bootc install to-disk --via-loopback --generic-image --wipe \
  --filesystem btrfs \
  --karg console=ttyS0,115200 \
  --root-ssh-authorized-keys /output/id.pub \
  --target-no-signature-verification \
  /output/disk.raw

log "Booting the disk in QEMU/KVM"
cp "$ovmf_vars" "$work/OVMF_VARS.fd"
qemu-system-x86_64 \
  -machine q35,accel=kvm -cpu host -smp 4 -m 6144 \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$work/OVMF_VARS.fd" \
  -drive file="$work/disk.raw",format=raw,if=virtio \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=net0 \
  -device virtio-vga -display none \
  -serial file:"$work/serial.log" \
  -monitor unix:"$work/monitor.sock",server,nowait \
  -pidfile "$work/qemu.pid" -daemonize

cleanup() {
  [[ -f $work/qemu.pid ]] && kill "$(cat "$work/qemu.pid")" 2>/dev/null || true
}
trap cleanup EXIT

ssh_opts=(-i "$work/id" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR)
vm() { ssh "${ssh_opts[@]}" root@127.0.0.1 "$@"; }

log "Waiting for SSH (up to 10 minutes)"
for _ in $(seq 120); do
  if vm true 2>/dev/null; then break; fi
  sleep 5
done
vm true || { echo "The VM never became reachable over SSH"; tail -50 "$work/serial.log"; exit 1; }

log "Waiting for boot to settle"
state=$(vm 'timeout 300 systemctl is-system-running --wait' || true)
echo "system state: $state"

log "Checks"
vm 'bash -s' <"$here/boot-checks.sh" | tee "$work/checks.txt"
status=${PIPESTATUS[0]}

log "Login screen screenshot"
sleep 20
if command -v socat >/dev/null; then
  echo "screendump $work/screen.ppm" | socat - UNIX-CONNECT:"$work/monitor.sock" >/dev/null || true
  sleep 2
  if [[ -f $work/screen.ppm ]] && command -v convert >/dev/null; then
    convert "$work/screen.ppm" "$work/screen.png" && rm -f "$work/screen.ppm"
  fi
fi

vm 'journalctl -b --no-pager -o short-monotonic' >"$work/journal.txt" 2>&1 || true
vm 'systemctl poweroff' 2>/dev/null || true
sleep 5
rm -f "$work/disk.raw"

exit "$status"

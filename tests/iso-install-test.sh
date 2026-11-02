#!/bin/bash
# End-to-end installer test: install an Atomarchy ISO onto a blank virtual disk
# with Anaconda (automated kickstart, same deployment commands as an
# interactive install), then boot the installed system and check it over SSH.
#
#   tests/iso-install-test.sh <iso> <payload-ref> <workdir>
#
# Needs: qemu-system-x86_64 + KVM, OVMF, xorriso, python3, ssh, socat.
# Artifacts left in <workdir>: install-serial.log, anaconda.log,
# install-*.png, checks.txt, journal.txt, screen.png.
set -euo pipefail

iso=$(realpath "${1:?iso}")
payload=${2:?payload image reference}
work=${3:?workdir}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$work"
work=$(cd "$work" && pwd)

log() { printf '\n\033[1;34m--> %s\033[0m\n' "$*"; }

first_file() {
  local file
  for file in "$@"; do
    if [[ -f $file ]]; then
      echo "$file"
      return 0
    fi
  done
  return 0
}
ovmf_code=$(first_file /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2/ovmf/OVMF_CODE.fd)
ovmf_vars=$(first_file /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd /usr/share/edk2/ovmf/OVMF_VARS.fd)
[[ -n $ovmf_code && -n $ovmf_vars ]] || { echo "OVMF firmware not found" >&2; exit 2; }
[[ -r /dev/kvm ]] || { echo "/dev/kvm not available" >&2; exit 2; }

pids=()
cleanup() {
  local pid
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  [[ -f $work/qemu.pid ]] && kill "$(cat "$work/qemu.pid")" 2>/dev/null || true
  rm -f "$work/disk.qcow2"
  chmod -R a+rX "$work" 2>/dev/null || true
}
trap cleanup EXIT

screenshot() {
  local sock=$1 name=$2
  echo "screendump $work/$name.ppm" | socat - "UNIX-CONNECT:$sock" >/dev/null 2>&1 || return 0
  sleep 1
  if [[ -f $work/$name.ppm ]] && command -v convert >/dev/null; then
    convert "$work/$name.ppm" "$work/$name.png" && rm -f "$work/$name.ppm"
  fi
}

# --- Installer kernel command line, taken from the ISO's own GRUB menu -------
log "Reading the ISO boot menu"
grub_cfg=$(xorriso -indev "$iso" -find / -name grub.cfg 2>/dev/null | tr -d "'" | head -1)
[[ -n $grub_cfg ]] || { echo "no grub.cfg in the ISO" >&2; exit 1; }
xorriso -osirrox on -indev "$iso" -extract "$grub_cfg" "$work/grub.cfg" >/dev/null 2>&1
linux_line=$(grep -m1 -E '^\s*linux(efi)?\s' "$work/grub.cfg")
initrd_line=$(grep -m1 -E '^\s*initrd(efi)?\s' "$work/grub.cfg")
kernel_path=$(awk '{print $2}' <<<"$linux_line")
initrd_path=$(awk '{print $2}' <<<"$initrd_line")
echo "kernel: $kernel_path  initrd: $initrd_path"
xorriso -osirrox on -indev "$iso" \
  -extract "$kernel_path" "$work/vmlinuz" \
  -extract "$initrd_path" "$work/initrd.img" >/dev/null 2>&1
[[ -s $work/vmlinuz && -s $work/initrd.img ]] || { echo "could not extract the installer kernel" >&2; exit 1; }
# Keep the live-root arguments; drop the kernel path and the interactive bits.
args=$(sed -E 's/^\s*linux(efi)?\s+\S+\s*//' <<<"$linux_line" |
  sed -E 's/(^| )(inst\.graphical|quiet|rhgb)( |$)/ /g; s/(^| )(inst\.graphical|quiet|rhgb)( |$)/ /g')
echo "installer arguments: $args"

# --- Kickstart: blank disk, one user, SSH key; deployment from the ISO's own
# interactive defaults (exactly what a person installing gets) -----------------
ssh-keygen -q -t ed25519 -N '' -f "$work/id" <<<y >/dev/null 2>&1 || true
mkdir -p "$work/http"
cat >"$work/http/ks.cfg" <<EOF
cmdline
lang en_US.UTF-8
keyboard us
timezone UTC --utc
network --bootproto=dhcp --activate
ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --disklabel=gpt
autopart --type=btrfs --noswap
rootpw --lock
user --name=atomarchy --groups=wheel --password=atomarchy --plaintext
sshkey --username=root "$(cat "$work/id.pub")"
%include /usr/share/anaconda/interactive-defaults.ks
poweroff
EOF
python3 -m http.server 8080 --bind 127.0.0.1 --directory "$work/http" >/dev/null 2>&1 &
pids+=($!)

# --- Install ---------------------------------------------------------------------
log "Installing from the ISO (Anaconda, automated)"
qemu-img create -q -f qcow2 "$work/disk.qcow2" 64G
cp "$ovmf_vars" "$work/OVMF_VARS.fd"
timeout 5400 qemu-system-x86_64 \
  -machine q35,accel=kvm -cpu host -smp 4 -m 6144 \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$work/OVMF_VARS.fd" \
  -kernel "$work/vmlinuz" -initrd "$work/initrd.img" \
  -append "$args inst.ks=http://10.0.2.2:8080/ks.cfg console=tty0 console=ttyS0,115200" \
  -drive file="$iso",media=cdrom,readonly=on \
  -drive file="$work/disk.qcow2",format=qcow2,if=virtio \
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
  -device virtio-serial-pci \
  -chardev file,id=anaconda,path="$work/anaconda.log" \
  -device virtserialport,chardev=anaconda,name=org.fedoraproject.anaconda.log.0 \
  -device virtio-vga -display none \
  -serial file:"$work/install-serial.log" \
  -monitor unix:"$work/install-monitor.sock",server,nowait \
  -no-reboot &
qemu_pid=$!
pids+=("$qemu_pid")

# A screenshot every 5 minutes shows where a stuck install stopped. Anaconda in
# cmdline mode waits after a crash: stop as soon as it reports one.
errors='Traceback \(most recent|PayloadInstallationError|installation failed|There was an error running the kickstart|The installer will now terminate|exited with the code|An unknown error has occurred'
anaconda_failed() {
  grep -qE "$errors" "$work/anaconda.log" "$work/install-serial.log" 2>/dev/null
}
minute=0
while kill -0 "$qemu_pid" 2>/dev/null; do
  sleep 60
  minute=$((minute + 1))
  if (( minute % 5 == 0 )); then
    screenshot "$work/install-monitor.sock" "install-$(printf '%03d' "$minute")min"
  fi
  if anaconda_failed; then
    sleep 20
    screenshot "$work/install-monitor.sock" install-error
    kill "$qemu_pid" 2>/dev/null || true
    break
  fi
done
qemu_status=0
wait "$qemu_pid" || qemu_status=$?

if anaconda_failed; then
  echo "Anaconda reported an error:"
  sed 's/\x1b\[[0-9;?=]*[a-zA-Z]//g' "$work/anaconda.log" "$work/install-serial.log" 2>/dev/null |
    grep -E -B6 -A6 "$errors" | tail -80
  exit 1
fi
if (( qemu_status != 0 )); then
  echo "QEMU exited with status $qemu_status during installation (124: timeout)"
  tail -60 "$work/install-serial.log"
  exit 1
fi
log "Installation finished in about ${minute} minutes"

# --- Boot the installed system ------------------------------------------------
log "Booting the installed system"
qemu-system-x86_64 \
  -machine q35,accel=kvm -cpu host -smp 4 -m 6144 \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$work/OVMF_VARS.fd" \
  -drive file="$work/disk.qcow2",format=qcow2,if=virtio \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2223-:22 -device virtio-net-pci,netdev=net0 \
  -device virtio-vga -display none \
  -serial file:"$work/serial.log" \
  -monitor unix:"$work/monitor.sock",server,nowait \
  -pidfile "$work/qemu.pid" -daemonize

ssh_opts=(-i "$work/id" -p 2223 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o LogLevel=ERROR)
vm() { ssh "${ssh_opts[@]}" root@127.0.0.1 "$@"; }
for _ in $(seq 120); do
  if vm true 2>/dev/null; then break; fi
  sleep 5
done
vm true || { echo "The installed system never became reachable over SSH"; tail -60 "$work/serial.log"; exit 1; }
vm 'timeout 300 systemctl is-system-running --wait' || true

log "Checks"
set +e
{
  vm 'bash -s' <"$here/boot-checks.sh"
  checks=$?
  # The installed system must follow the signed registry image, not the
  # ISO's local copy.
  spec=$(vm "bootc status --json | jq -r '.spec.image.image // empty'")
  if [[ $spec == "$payload" ]]; then
    echo "PASS  follows $payload"
  else
    echo "FAIL  follows '${spec}' instead of $payload"
    checks=$((checks + 1))
  fi
  if vm 'test -s /etc/pki/containers/atomarchy.pub'; then
    echo "PASS  signature policy key present"
  else
    echo "FAIL  signature policy key missing"
    checks=$((checks + 1))
  fi
  if vm 'id atomarchy >/dev/null'; then
    echo "PASS  user created by the installer"
  else
    echo "FAIL  installer user missing"
    checks=$((checks + 1))
  fi
  echo "INSTALL-CHECKS-FAILED=$checks"
} | tee "$work/checks.txt"
set -e

sleep 20
screenshot "$work/monitor.sock" screen
vm 'journalctl -b --no-pager -o short-monotonic' >"$work/journal.txt" 2>&1 || true
vm 'systemctl poweroff' 2>/dev/null || true

grep -q '^INSTALL-CHECKS-FAILED=0$' "$work/checks.txt"

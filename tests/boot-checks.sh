#!/bin/bash
# Runs inside the booted Atomarchy VM (as root, over SSH) from boot-test.sh.
# Exit status: number of failed checks.
set -u

pass=0
fail=0
ok() { echo "PASS  $*"; pass=$((pass + 1)); }
ko() { echo "FAIL  $*"; fail=$((fail + 1)); }
warn() { echo "WARN  $*"; }

flavor=$(jq -r '."image-flavor"' /usr/share/ublue-os/image-info.json)

# Units that cannot work in a VM without the matching hardware.
allowed_failures=(lactd.service)

echo "== $(jq -r '"\(."image-name") \(.version)"' /usr/share/ublue-os/image-info.json) on $(uname -r)"

booted=$(bootc status --json 2>/dev/null | jq -r '.status.booted.image.image.image // empty')
if [[ -n $booted ]]; then ok "bootc reports the booted image: $booted"; else ko "bootc status has no booted image"; fi

failed=()
while read -r unit _; do
  [[ -n $unit ]] || continue
  [[ " ${allowed_failures[*]} " == *" $unit "* ]] && { warn "failed (expected in a VM): $unit"; continue; }
  failed+=("$unit")
done < <(systemctl --failed --no-legend --plain)
if (( ${#failed[@]} == 0 )); then
  ok "no failed system units"
else
  ko "failed units: ${failed[*]}"
  for unit in "${failed[@]}"; do
    journalctl -b -u "$unit" --no-pager -n 15 | sed 's/^/      /'
  done
fi

if systemctl is-active --quiet sddm.service; then ok "SDDM is running"; else ko "SDDM is not running"; fi
if pgrep -u sddm -f -i hyprland >/dev/null; then
  ok "SDDM greeter compositor (Hyprland) is running"
else
  warn "no Hyprland greeter process (virtual GPU without 3D?)"
  journalctl -b -u sddm --no-pager -n 30 | sed 's/^/      /'
fi
if systemctl is-active --quiet docker.socket; then ok "docker.socket active"; else ko "docker.socket inactive"; fi
if systemctl is-enabled --quiet uupd.timer; then ok "uupd.timer enabled"; else ko "uupd.timer not enabled"; fi
if profile=$(powerprofilesctl get 2>/dev/null); then ok "power profiles answer: $profile"; else ko "powerprofilesctl failed"; fi
if [[ -f /usr/share/wayland-sessions/omarchy.desktop ]]; then ok "Omarchy session available"; else ko "Omarchy session missing"; fi
if [[ $(plymouth-set-default-theme 2>/dev/null) == omarchy ]]; then ok "Plymouth theme omarchy"; else ko "Plymouth theme not omarchy"; fi

if [[ $flavor == gaming ]]; then
  if [[ $(uname -r) == *ogc* ]]; then ok "running the OGC kernel"; else ko "not running the OGC kernel: $(uname -r)"; fi
  if [[ -c /dev/ntsync ]]; then ok "/dev/ntsync present"; else ko "/dev/ntsync missing"; fi
  if systemctl is-active --quiet tuned.service; then ok "tuned running: $(tuned-adm active | sed 's/.*: //')"; else ko "tuned not running"; fi
  if [[ $(sysctl -n vm.max_map_count) == 2147483642 ]]; then ok "gaming sysctl applied"; else ko "vm.max_map_count = $(sysctl -n vm.max_map_count)"; fi
fi

echo
echo "RESULT: $pass passed, $fail failed ($flavor, booted)"
exit "$fail"

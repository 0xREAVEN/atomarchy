#!/bin/bash
# Atomarchy smoke tests, run inside a built image (no boot, no GPU):
#
#   podman run --rm --network=none -v ./tests:/tests:ro <image> /tests/smoke.sh
#
# The flavour (main / gaming) is read from the image itself. Exit status is
# the number of failed checks (0 = all passed).
set -u

pass=0
fail=0
ok() { echo "PASS  $*"; pass=$((pass + 1)); }
ko() { echo "FAIL  $*"; fail=$((fail + 1)); }
check() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then ok "$description"; else ko "$description"; fi
}
section() { printf '\n== %s\n' "$*"; }

info=/usr/share/ublue-os/image-info.json
flavor=$(jq -r '."image-flavor"' "$info" 2>/dev/null)

section "Image ($(jq -r '"\(."image-name") \(.version) \(."image-tag")"' "$info" 2>/dev/null))"
rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}\n' omarchy omarchy-settings hyprland quickshell uwsm sddm kernel mesa-dri-drivers 2>&1
check "image-info.json is valid" jq -e '."image-name" and ."image-ref" and ."fedora-version" and ."omarchy-version"' "$info"
check "image flavour is main or gaming" bash -c "[[ $flavor == main || $flavor == gaming ]]"
check "os-release names the variant" bash -c 'source /usr/lib/os-release; [[ $NAME == Atomarchy && $ID == fedora && -n $VARIANT_ID && -n $IMAGE_VERSION ]]'

section "Omarchy"
for command in Hyprland hyprctl start-hyprland quickshell uwsm omarchy omarchy-menu omarchy-theme-set \
  omarchy-launch-shell powerprofilesctl gum mise starship chromium docker foot nvim; do
  check "command $command" command -v "$command"
done
check "OMARCHY_PATH tree" test -d /usr/share/omarchy/shell -a -d /usr/share/omarchy/themes -a -f /usr/share/omarchy/default/hypr/bootstrap.lua
check "at least 20 themes" bash -c '(( $(ls /usr/share/omarchy/themes | wc -l) >= 20 ))'
check "Omarchy defaults in /etc/skel" test -f /etc/skel/.config/hypr/hyprland.lua
check "Omarchy CLI routes" bash -c 'omarchy 2>&1 | grep -qi theme'
check "theme list" bash -c 'source /etc/profile.d/omarchy.sh; omarchy-theme-list | grep -q "Tokyo Night"'
check "Chromium under Omarchy's names" test -x /usr/bin/chromium -a -f /usr/share/applications/chromium.desktop
check "single visible Chromium launcher" grep -q '^NoDisplay=true' /usr/share/applications/chromium-browser.desktop
check "no fcitx variables without fcitx5" test ! -e /usr/lib/environment.d/10-omarchy-fcitx.conf

section "Atomic adaptation"
for override in /usr/share/atomarchy/bin/*; do
  check "override ${override##*/}" cmp -s "$override" "/usr/bin/${override##*/}"
done
check "no direct dnf transactions left" bash -c '! grep -lE "(sudo |^\s*)dnf5? (install|remove|upgrade|distro-sync|autoremove)" /usr/bin/omarchy-* | grep -vx /usr/bin/omarchy-dev-pkg-test'
check "bash syntax of every omarchy-* command" bash -c 'for f in /usr/bin/omarchy-*; do head -1 "$f" | grep -q bash || continue; bash -n "$f" || exit 1; done'
check "pkg present" omarchy-pkg-present hyprland
check "pkg missing" omarchy-pkg-missing definitely-not-a-package
check "pkg add is a no-op for installed packages" omarchy-pkg-add hyprland jq
check "snapshot create reports Snapper absent (127)" bash -c 'omarchy-snapshot create; [[ $? == 127 ]]'
check "kernel get" omarchy-kernel get
check "no Limine / mkinitcpio leftovers" test ! -e /etc/limine-entry-tool.d -a ! -e /etc/mkinitcpio.conf.d

section "Login, boot splash, session"
check "SDDM is the display manager" bash -c '[[ $(readlink -f /etc/systemd/system/display-manager.service) == */sddm.service ]]'
check "graphical target by default" bash -c '[[ $(systemctl get-default) == graphical.target ]]'
check "SDDM uses the Omarchy theme" grep -qx 'Current=omarchy' /etc/sddm.conf.d/10-theme.conf
check "SDDM greeter runs on Hyprland" grep -q 'start-hyprland' /etc/sddm.conf.d/10-wayland.conf
check "Omarchy session runs the Atomarchy wrapper" grep -q '^Exec=/usr/libexec/atomarchy/session' /usr/share/wayland-sessions/omarchy.desktop
check "plain Hyprland sessions hidden" bash -c 'for f in /usr/share/wayland-sessions/hyprland*.desktop; do grep -q "^Hidden=true" "$f" || exit 1; done'
check "Plymouth theme is omarchy" bash -c '[[ $(plymouth-set-default-theme) == omarchy ]]'
check "initramfs carries the Omarchy theme" bash -c 'lsinitrd /usr/lib/modules/*/initramfs.img | grep -q "plymouth/themes/omarchy"'
check "splash kernel arguments" grep -q rhgb /usr/lib/bootc/kargs.d/10-atomarchy-splash.toml

section "Services and updates"
check "uupd timer enabled" test -L /etc/systemd/system/timers.target.wants/uupd.timer
check "rpm-ostree automatic updates disabled" bash -c '! systemctl is-enabled --quiet rpm-ostreed-automatic.timer'
check "docker.socket enabled" test -L /etc/systemd/system/sockets.target.wants/docker.socket
check "Bazaar installed" rpm -q bazaar
check "Homebrew integration installed" rpm -q ublue-brew
check "ujust loads the Atomarchy recipes" bash -c 'ujust --summary | tr " " "\n" | grep -qx atomarchy-doctor'
check "build-time repositories disabled" bash -c '! dnf5 repolist --enabled 2>/dev/null | grep -qiE "^terra|ublue-os:packages"'

section "Signature policy"
if [[ -s /etc/pki/containers/atomarchy.pub ]]; then
  check "policy requires the project key" jq -e '.transports.docker | to_entries | map(select(.key | endswith("/atomarchy"))) | .[0].value[0].keyPath == "/etc/pki/containers/atomarchy.pub"' /etc/containers/policy.json
  check "sigstore attachments enabled" test -f /etc/containers/registries.d/atomarchy.yaml
  check "image-ref is signature-verified" bash -c "jq -r '.\"image-ref\"' $info | grep -q '^ostree-image-signed:'"
else
  echo "SKIP  no project key in this build (keys/cosign.pub)"
fi

if [[ $flavor == "main" ]]; then
  section "Main flavour"
  check "Fedora kernel" bash -c '! rpm -q kernel | grep -q ogc'
  check "Omarchy power profiles daemon" rpm -q omarchy-power-profiles-daemon
fi

if [[ $flavor == "gaming" ]]; then
  section "Gaming flavour"
  check "Bazzite OGC kernel" bash -c 'rpm -q kernel | grep -q ogc'
  check "one kernel only" bash -c '(( $(ls /usr/lib/modules | wc -l) == 1 ))'
  check "kernel version locked" bash -c 'dnf5 versionlock list 2>/dev/null | grep -q kernel'
  for kmod in xone new-lg4ff hid-fanatecff hid-tmff2 t150-driver ryzen_smu zenergy; do
    check "kernel module $kmod" bash -c "rpm -qa | grep -q -- 'kmod-.*${kmod}'"
  done
  check "ntsync loaded at boot" grep -qx ntsync /usr/lib/modules-load.d/atomarchy-ntsync.conf
  check "Mesa only from terra-mesa" bash -c '[[ -z $(dnf5 repoquery --installed --qf "%{name} %{from_repo} %{sourcerpm}\n" "mesa-*" | awk "\$3 ~ /^mesa-[0-9]/ && \$2 != \"terra-mesa\"") ]]'
  check "32-bit Vulkan drivers" rpm -q mesa-vulkan-drivers.i686
  for package in steam terra-gamescope terra-mangohud umu-launcher vkBasalt lact tuned-ppd; do
    check "package $package" rpm -q "$package"
  done
  check "power-profiles-daemon replaced by tuned-ppd" bash -c '! rpm -q omarchy-power-profiles-daemon'
  check "lactd enabled" test -L /etc/systemd/system/multi-user.target.wants/lactd.service
  check "performance mode uses the Atomarchy tuned profile" grep -qx 'performance=throughput-performance-atomarchy' /etc/tuned/ppd.conf
  check "gaming sysctl sorts after Omarchy's" bash -c '[[ 99-zz-atomarchy-gaming.conf > 99-omarchy-sysctl.conf ]] && test -f /usr/lib/sysctl.d/99-zz-atomarchy-gaming.conf'
  check "gaming environment" grep -qx 'PROTON_USE_NTSYNC=1' /usr/lib/environment.d/60-atomarchy-gaming.conf
  check "gaming ujust recipes" bash -c 'ujust --summary | tr " " "\n" | grep -qx toggle-amdgpu-overdrive'
  check "tmpfiles rules valid" systemd-tmpfiles --dry-run --create /usr/lib/tmpfiles.d/atomarchy-gaming-thp.conf
fi

section "User seeding (account created before the image)"
asuser() {
  setpriv --reuid tester --regid tester --init-groups \
    env -i HOME=/home/tester USER=tester LOGNAME=tester PATH=/usr/local/bin:/usr/bin:/bin bash -lc "$1"
}
export -f asuser
useradd -m -s /bin/bash tester >/dev/null 2>&1 || true
rm -rf /home/tester/.config/hypr /home/tester/.local/state
mkdir -p /home/tester/.config/kitty && echo "# mine" >/home/tester/.config/kitty/kitty.conf
cat >/home/tester/.bashrc <<'RC'
if [ -f /etc/bashrc ]; then . /etc/bashrc; fi
if [ -d ~/.bashrc.d ]; then for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done; fi
unset rc
RC
chown -R tester: /home/tester
asuser /usr/libexec/atomarchy/user-init
check "Hyprland config seeded" test -f /home/tester/.config/hypr/hyprland.lua
check "existing user file kept" grep -q mine /home/tester/.config/kitty/kitty.conf
check "kept files listed" bash -c 'grep -q kitty /home/tester/.local/state/atomarchy/skipped-*.txt'
check "shell hook in ~/.bashrc.d" test -f /home/tester/.bashrc.d/50-omarchy.sh
check "migrations marked as applied" bash -c '(( $(ls /home/tester/.local/state/omarchy/migrations | wc -l) > 10 ))'
check "Omarchy user setup completed" test -f /home/tester/.local/state/omarchy/done/finalize-user
check "theme state generated" test -d /home/tester/.local/state/omarchy/current
check "default browser is Chromium" bash -c "asuser 'xdg-settings get default-web-browser' | grep -qx chromium.desktop"
asuser '/usr/libexec/atomarchy/user-init --reset' >/dev/null 2>&1
check "reset replaces and backs up" bash -c '! grep -q mine /home/tester/.config/kitty/kitty.conf && grep -rq mine /home/tester/.local/state/atomarchy/backup-*'
check "interactive shell loads Omarchy" bash -c "asuser 'bash -ic \"alias ls\"' 2>/dev/null | grep -q eza"
userdel -r tester >/dev/null 2>&1

printf '\nRESULT: %d passed, %d failed (%s)\n' "$pass" "$fail" "$flavor"
exit "$fail"

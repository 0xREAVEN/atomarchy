#!/bin/bash
# Smoke tests run inside the built image: podman run --rm -v ./tests:/tests:ro <image> bash /tests/smoke.sh
set -u
pass=0; fail=0
ok()  { echo "PASS  $*"; pass=$((pass+1)); }
ko()  { echo "FAIL  $*"; fail=$((fail+1)); }
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else ko "$d"; fi; }

echo "== versions"
rpm -q omarchy omarchy-settings hyprland quickshell uwsm xdg-desktop-portal-hyprland mise starship chromium moby-engine fcitx5 2>&1
rpm -q kernel plasma-workspace tuned-ppd steam 2>&1
jq . /usr/share/ublue-os/image-info.json

echo "== presence"
for c in Hyprland hyprctl start-hyprland quickshell uwsm omarchy omarchy-menu omarchy-theme-set omarchy-launch-shell powerprofilesctl gum mise starship chromium-browser docker foot nvim; do
  check "command $c" command -v "$c"
done
check "OMARCHY_PATH tree" test -d /usr/share/omarchy/shell -a -d /usr/share/omarchy/themes -a -f /usr/share/omarchy/default/hypr/bootstrap.lua
check "themes >= 15" bash -c '(( $(ls /usr/share/omarchy/themes | wc -l) >= 15 ))'
check "chromium alias" test -x /usr/bin/chromium
check "chromium.desktop alias" bash -c 'desktop-file-validate /usr/share/applications/chromium.desktop >/dev/null 2>&1 || grep -q "^Exec=" /usr/share/applications/chromium.desktop'
check "single visible chromium entry" grep -q '^NoDisplay=true' /usr/share/applications/chromium-browser.desktop
check "skel hyprland.lua" test -f /etc/skel/.config/hypr/hyprland.lua
check "session file is ours" grep -q omarchy-atomic/session /usr/share/wayland-sessions/omarchy.desktop
check "plain hyprland session hidden" bash -c 'for f in /usr/share/wayland-sessions/hyprland*.desktop; do grep -q "^Hidden=true" "$f" || exit 1; done'
check "just recipes parse" bash -c 'just --justfile /usr/share/ublue-os/justfile --list | grep -q omarchy-setup'
check "fcitx env moved to uwsm" test -f /usr/share/uwsm/env.d/20-omarchy-fcitx -a ! -f /usr/lib/environment.d/10-omarchy-fcitx.conf
check "bazzite zram kept" test ! -f /usr/lib/systemd/zram-generator.conf.d/90-omarchy.conf
check "bazzite sysctl kept" test ! -f /etc/sysctl.d/99-omarchy-sysctl.conf
check "plymouth conf kept" bash -c '! grep -q "Theme=omarchy" /etc/plymouth/plymouthd.conf'
check "flatpak service enabled" test -L /etc/systemd/system/multi-user.target.wants/omarchy-atomic-flatpaks.service
check "docker.socket enabled" test -L /etc/systemd/system/sockets.target.wants/docker.socket

echo "== overrides installed"
for f in /usr/share/omarchy-atomic/bin/*; do
  n=${f##*/}
  check "override $n" cmp -s "$f" "/usr/bin/$n"
done
check "no direct dnf install/remove left (except allowed)" bash -c '! grep -lE "(sudo |^\s*)dnf5? (install|remove|upgrade|distro-sync|autoremove)" /usr/bin/omarchy-* | grep -vE "omarchy-(dev-pkg-test|realtime-repair|upgrade-to-quattro)$"'
check "bash syntax of all omarchy-* commands" bash -c 'for f in /usr/bin/omarchy-*; do head -1 "$f" | grep -q bash || continue; bash -n "$f" || exit 1; done'

echo "== omarchy CLI"
check "omarchy --help routes" bash -c 'omarchy 2>&1 | grep -qi theme'
check "omarchy-theme-list" bash -c 'source /etc/profile.d/omarchy.sh; omarchy-theme-list | grep -q "Tokyo Night"'
check "omarchy-pkg-present works" omarchy-pkg-present hyprland
check "omarchy-pkg-missing works" omarchy-pkg-missing definitely-not-a-package
check "omarchy-pkg-add is a no-op for installed pkgs" omarchy-pkg-add hyprland jq
check "omarchy-snapshot create returns 127" bash -c 'omarchy-snapshot create; [[ $? == 127 ]]'
check "omarchy-kernel get" omarchy-kernel get

echo "== Hyprland config parses (headless)"
check "hyprland --version" Hyprland --version

echo "== user seeding (fresh user, existing home)"
asuser() { setpriv --reuid tester --regid tester --init-groups env -i HOME=/home/tester USER=tester LOGNAME=tester PATH=/usr/local/bin:/usr/bin:/bin bash -lc "$1"; }
export -f asuser
useradd -m -s /bin/bash tester >/dev/null 2>&1 || true
# Simulate an account created before the image: start from Bazzite-like home.
rm -rf /home/tester/.config/hypr /home/tester/.local/state
mkdir -p /home/tester/.config/kitty && echo "# mine" > /home/tester/.config/kitty/kitty.conf
# Fedora/Bazzite default ~/.bashrc (sources ~/.bashrc.d), as on a pre-existing account.
cat > /home/tester/.bashrc <<'RC'
if [ -f /etc/bashrc ]; then . /etc/bashrc; fi
if [ -d ~/.bashrc.d ]; then for rc in ~/.bashrc.d/*; do [ -f "$rc" ] && . "$rc"; done; fi
unset rc
RC
chown -R tester: /home/tester
asuser '/usr/libexec/omarchy-atomic/user-init' ; echo "user-init exit=$?"
check "seeded hyprland.lua" test -f /home/tester/.config/hypr/hyprland.lua
check "user kitty.conf kept" grep -q mine /home/tester/.config/kitty/kitty.conf
check "skipped list written" bash -c 'grep -q kitty /home/tester/.local/state/omarchy-atomic/skipped-*.txt'
check "bashrc.d hook" test -f /home/tester/.bashrc.d/50-omarchy.sh
check "migration markers seeded" bash -c '(( $(ls /home/tester/.local/state/omarchy/migrations | wc -l) > 10 ))'
check "provision-user completed (finalize marker)" test -f /home/tester/.local/state/omarchy/done/finalize-user
check "default browser = chromium.desktop" bash -c "asuser 'xdg-settings get default-web-browser' | grep -qx chromium.desktop"
check "theme state generated" bash -c 'ls /home/tester/.local/state/omarchy/current/ >/dev/null'
asuser '/usr/libexec/omarchy-atomic/user-init --reset'
check "reset replaces kitty + backup" bash -c '! grep -q mine /home/tester/.config/kitty/kitty.conf && grep -rq mine /home/tester/.local/state/omarchy-atomic/backup-*'
check "interactive bash loads omarchy rc" bash -c "asuser 'bash -ic \"alias ls\"' 2>/dev/null | grep -q eza"
userdel -r tester >/dev/null 2>&1

echo
echo "RESULT: $pass passed, $fail failed"
(( fail == 0 ))

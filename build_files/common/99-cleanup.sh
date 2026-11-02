# shellcheck shell=bash
# Leave the image as bootc expects it: repositories in their runtime state,
# no build caches, /var recreated at boot by tmpfiles.d.

# Runtime repositories: Omadora and Hyprland stay enabled for
# `omarchy pkg add` (rpm-ostree layering); Terra and ublue-os/packages are
# build-time only, as on Bazzite.
repos_set_enabled 0 'terra*' 'copr:copr.fedorainfracloud.org:ublue-os:packages'

dnf5 clean all
rm -rf /var/lib/dnf /var/log/dnf5.log* /var/tmp/* /var/cache/ldconfig/aux-cache
# Created by package scriptlets at build time, recreated at boot by
# tmpfiles.d (system_files/common/usr/lib/tmpfiles.d/atomarchy.conf).
rm -rf /var/lib/plocate /var/lib/power-profiles-daemon /var/lib/texmf
find /var/log -type f -delete 2>/dev/null || true

# bootc deploys kernels itself: /boot stays empty in the image (kernel RPM
# scriptlets drop System.map, config, loader entries there).
find /boot -mindepth 1 -delete 2>/dev/null || true

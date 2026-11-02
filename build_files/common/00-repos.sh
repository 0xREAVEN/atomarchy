# shellcheck shell=bash
# Third-party repositories. Everything is installed at build time; the image
# keeps only the repositories users may need for `omarchy pkg add`
# (rpm-ostree layering): Omadora and the Hyprland COPR.
#
#   kammer/omadora        omarchy, omarchy-settings, Omarchy apps (Fedora port)
#   lionheartp/Hyprland   Hyprland 0.57, Quickshell 0.3, portals
#   ublue-os/packages     Bazaar, Homebrew integration (ublue-brew)
#   Terra                 uwsm, mise, starship, lazygit, uupd, gaming stack
#                         (disabled after the build, as Bazzite does)

dnf5 -y install dnf5-plugins

dnf5 -y copr enable kammer/omadora
dnf5 -y copr enable lionheartp/Hyprland
dnf5 -y copr enable ublue-os/packages

if ! rpm -q terra-release >/dev/null 2>&1; then
  dnf5 -y install --nogpgcheck \
    --repofrompath "terra,https://repos.fyralabs.com/terra${FEDORA_VERSION}" \
    terra-release terra-release-extras terra-release-mesa
fi
# Terra is enabled per transaction (--enable-repo) so it never shadows Fedora
# packages implicitly.
repos_set_enabled 0 'terra*'

dnf5 -y makecache

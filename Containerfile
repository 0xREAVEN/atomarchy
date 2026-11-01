# Bazzite + Omarchy 4 (Hyprland / Quickshell) as a bootc image.
#
# Base: any Bazzite desktop image. The default is the KDE image; choose the
# NVIDIA or GNOME flavour with --build-arg BASE_IMAGE=..., e.g.
#   ghcr.io/ublue-os/bazzite-nvidia-open
#   ghcr.io/ublue-os/bazzite-gnome
# Avoid the -deck images: they boot straight into Steam Gaming Mode.

ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite
ARG BASE_TAG=stable

FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

FROM ${BASE_IMAGE}:${BASE_TAG}

# Identity written into /usr/share/ublue-os/image-info.json so ujust,
# uupd and `omarchy update` know which image to follow.
ARG IMAGE_NAME=bazzite-omarchy
ARG IMAGE_VENDOR=local
ARG IMAGE_REGISTRY=ghcr.io/local
ARG IMAGE_SIGNED=0

# Optional pieces (1 = install, 0 = skip).
ARG WITH_DOCKER=1
ARG WITH_FCITX=1
ARG WITH_PLYMOUTH_THEME=0

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_NAME="${IMAGE_NAME}" IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_REGISTRY="${IMAGE_REGISTRY}" IMAGE_SIGNED="${IMAGE_SIGNED}" \
    WITH_DOCKER="${WITH_DOCKER}" WITH_FCITX="${WITH_FCITX}" \
    WITH_PLYMOUTH_THEME="${WITH_PLYMOUTH_THEME}" \
    /ctx/build_files/build.sh

RUN bootc container lint

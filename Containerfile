# Atomarchy: Omarchy 4 (Hyprland + Quickshell) as Fedora Atomic bootc images.
#
#   podman build --target atomarchy        -t localhost/atomarchy .
#   podman build --target atomarchy-gaming -t localhost/atomarchy-gaming .
#
# atomarchy         ghcr.io/ublue-os/base-main + Omarchy (Omadora RPMs) adapted
#                   to an atomic system
# atomarchy-gaming  atomarchy + Bazzite's OGC kernel and modules, Terra's gaming
#                   stack (Mesa, Steam, gamescope, MangoHud), LACT, tuned

ARG FEDORA_VERSION=44
ARG BASE_IMAGE=ghcr.io/ublue-os/base-main
# Bazzite's gaming kernel, published by Universal Blue as akmods images.
# Renovate keeps KERNEL_VERSION in sync with the tags of ghcr.io/ublue-os/akmods.
ARG KERNEL_FLAVOR=ogc
# renovate: datasource=docker depName=ghcr.io/ublue-os/akmods extractVersion=^ogc-44-(?<version>.+)$ versioning=loose
ARG KERNEL_VERSION=7.2.11-ogc4.1.fc44

FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods
FROM ghcr.io/ublue-os/akmods-extra:${KERNEL_FLAVOR}-${FEDORA_VERSION}-${KERNEL_VERSION} AS akmods-extra

FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY keys /keys

# ---------------------------------------------------------------------------
FROM ${BASE_IMAGE}:${FEDORA_VERSION} AS atomarchy

ARG FEDORA_VERSION
ARG IMAGE_REGISTRY=ghcr.io/0xreaven
ARG IMAGE_VENDOR=0xreaven
ARG IMAGE_TAG=stable
ARG IMAGE_VERSION
ARG PROJECT_URL=https://github.com/0xREAVEN/atomarchy

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=tmpfs,dst=/tmp \
    FEDORA_VERSION="${FEDORA_VERSION}" IMAGE_NAME=atomarchy IMAGE_FLAVOR=main \
    IMAGE_REGISTRY="${IMAGE_REGISTRY}" IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_TAG="${IMAGE_TAG}" IMAGE_VERSION="${IMAGE_VERSION}" PROJECT_URL="${PROJECT_URL}" \
    /ctx/build_files/build.sh common

RUN bootc container lint

# ---------------------------------------------------------------------------
FROM atomarchy AS atomarchy-gaming

ARG FEDORA_VERSION
ARG IMAGE_REGISTRY=ghcr.io/0xreaven
ARG IMAGE_VENDOR=0xreaven
ARG IMAGE_TAG=stable
ARG IMAGE_VERSION
ARG PROJECT_URL=https://github.com/0xREAVEN/atomarchy

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=akmods,source=/kernel-rpms,target=/tmp/kernel-rpms \
    --mount=type=bind,from=akmods,source=/rpms/common,target=/tmp/rpms/common \
    --mount=type=bind,from=akmods,source=/rpms/kmods,target=/tmp/rpms/kmods \
    --mount=type=bind,from=akmods-extra,source=/rpms/extra,target=/tmp/rpms/extra \
    --mount=type=bind,from=akmods-extra,source=/rpms/kmods,target=/tmp/rpms/kmods-extra \
    --mount=type=cache,dst=/var/cache/libdnf5 \
    FEDORA_VERSION="${FEDORA_VERSION}" IMAGE_NAME=atomarchy-gaming IMAGE_FLAVOR=gaming \
    IMAGE_REGISTRY="${IMAGE_REGISTRY}" IMAGE_VENDOR="${IMAGE_VENDOR}" \
    IMAGE_TAG="${IMAGE_TAG}" IMAGE_VERSION="${IMAGE_VERSION}" PROJECT_URL="${PROJECT_URL}" \
    /ctx/build_files/build.sh gaming

RUN bootc container lint

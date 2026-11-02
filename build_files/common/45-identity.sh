# shellcheck shell=bash
# Image identity: /usr/share/ublue-os/image-info.json (read by ujust, uupd and
# `omarchy update`) and os-release. Also run by the gaming stage, which only
# changes IMAGE_NAME / IMAGE_FLAVOR.

: "${IMAGE_NAME:=atomarchy}"
: "${IMAGE_FLAVOR:=main}"
: "${IMAGE_VENDOR:=atomarchy}"
: "${IMAGE_REGISTRY:=ghcr.io/atomarchy}"
: "${IMAGE_TAG:=stable}"
: "${IMAGE_VERSION:=${FEDORA_VERSION}.$(date -u +%Y%m%d)}"
: "${PROJECT_URL:=https://github.com/0xREAVEN/atomarchy}"

signed=0
[[ -s /etc/pki/containers/atomarchy.pub ]] && signed=1

# --- Identity ----------------------------------------------------------------
if (( signed )); then
  image_ref="ostree-image-signed:docker://${IMAGE_REGISTRY}/${IMAGE_NAME}"
else
  image_ref="ostree-unverified-registry:${IMAGE_REGISTRY}/${IMAGE_NAME}"
fi

mkdir -p /usr/share/ublue-os
jq -n \
  --arg name "$IMAGE_NAME" --arg flavor "$IMAGE_FLAVOR" --arg vendor "$IMAGE_VENDOR" \
  --arg ref "$image_ref" --arg tag "$IMAGE_TAG" --arg fedora "$FEDORA_VERSION" \
  --arg version "$IMAGE_VERSION" --arg omarchy "$(rpm -q --qf '%{VERSION}-%{RELEASE}' omarchy)" \
  '{
    "image-name": $name, "image-flavor": $flavor, "image-vendor": $vendor,
    "image-ref": $ref, "image-tag": $tag, "image-branch": $tag,
    "base-image-name": "base-main", "fedora-version": $fedora,
    "version": $version, "version-pretty": "Atomarchy \($version) (\($tag))",
    "omarchy-version": $omarchy
  }' >/usr/share/ublue-os/image-info.json

# os-release: keep ID=fedora (dnf, rpm-ostree and Anaconda key on it) and
# describe the variant on top, as the os-release specification intends.
pretty="Atomarchy ${FEDORA_VERSION}"
[[ $IMAGE_FLAVOR == "gaming" ]] && pretty+=" Gaming"
set_os_release() {
  local key=$1 value=$2
  if grep -q "^${key}=" /usr/lib/os-release; then
    sed -i "s|^${key}=.*|${key}=\"${value}\"|" /usr/lib/os-release
  else
    echo "${key}=\"${value}\"" >>/usr/lib/os-release
  fi
}
set_os_release NAME "Atomarchy"
set_os_release PRETTY_NAME "$pretty"
set_os_release VARIANT "${IMAGE_FLAVOR^}"
set_os_release VARIANT_ID "$IMAGE_NAME"
set_os_release IMAGE_ID "$IMAGE_NAME"
set_os_release IMAGE_VERSION "$IMAGE_VERSION"
set_os_release DEFAULT_HOSTNAME "atomarchy"
set_os_release HOME_URL "$PROJECT_URL"
set_os_release DOCUMENTATION_URL "$PROJECT_URL#readme"
set_os_release SUPPORT_URL "$PROJECT_URL/discussions"
set_os_release BUG_REPORT_URL "$PROJECT_URL/issues"

# shellcheck shell=bash
# Same identity step as the common stage, with IMAGE_NAME / IMAGE_FLAVOR of
# the gaming image (set by the Containerfile).
# shellcheck source=build_files/common/45-identity.sh
source "$CTX/build_files/common/45-identity.sh"

# shellcheck shell=bash
# Shared helpers for Atomarchy build steps. Sourced by build.sh.

CTX=${CTX:-/ctx}
# Used by the step files sourced after this library.
export FILES=$CTX/system_files
export PACKAGES=$CTX/build_files/packages

log() {
  printf '\n\033[1;32m==> %s\033[0m\n' "$*"
}

warn() {
  printf '\033[1;33mwarning: %s\033[0m\n' "$*" >&2
}

die() {
  printf '\033[1;31merror: %s\033[0m\n' "$*" >&2
  exit 1
}

# Package list files: one package per line, # comments allowed.
read_list() {
  grep -vE '^\s*(#|$)' "$1" | sed 's/\s*#.*$//'
}

# Copy a system_files tree (common, gaming) over / and fix modes of the
# executables it ships.
install_tree() {
  local tree=$FILES/$1
  [[ -d $tree ]] || die "missing system_files/$1"
  cp -a "$tree/." /
}

# Enable or disable every repository whose id matches a glob.
repos_set_enabled() {
  local value=$1
  shift
  local pattern
  for pattern in "$@"; do
    dnf5 -y config-manager setopt "${pattern}.enabled=${value}" >/dev/null
  done
}

# The kernel the image boots: there is exactly one in an image.
image_kernel() {
  local kernels
  mapfile -t kernels < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
  (( ${#kernels[@]} == 1 )) || die "expected one kernel in /usr/lib/modules, found: ${kernels[*]}"
  printf '%s\n' "${kernels[0]}"
}

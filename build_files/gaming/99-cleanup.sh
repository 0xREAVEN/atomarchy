# shellcheck shell=bash
# tuned state, recreated at boot (usr/lib/tmpfiles.d/atomarchy-gaming.conf).
rm -rf /var/lib/tuned /var/log/tuned
# shellcheck source=build_files/common/99-cleanup.sh
source "$CTX/build_files/common/99-cleanup.sh"

# shellcheck shell=bash
# Gaming tunables (from Bazzora and Bazzite), services and power profiles.

install_tree gaming

systemctl enable lactd.service
systemctl enable tuned.service tuned-ppd.service

# power-profiles "performance" uses the Atomarchy profile, which keeps the
# write-back limits of 99-zz-atomarchy-gaming.conf.
ppd=/etc/tuned/ppd.conf
[[ -f $ppd ]] || die "$ppd missing (tuned-ppd layout changed?)"
sed -i 's/^performance=throughput-performance$/performance=throughput-performance-atomarchy/' "$ppd"
grep -qx 'performance=throughput-performance-atomarchy' "$ppd" || die "could not map the performance profile in $ppd"

# shellcheck shell=bash
# Services and container signature policy.

: "${IMAGE_REGISTRY:=ghcr.io/atomarchy}"

# --- Services --------------------------------------------------------------
# uupd updates the image, Flatpaks, Homebrew and distrobox in the background,
# as on Bazzite; it replaces rpm-ostree's own automatic updates.
systemctl enable uupd.timer
systemctl disable rpm-ostreed-automatic.timer 2>/dev/null || true
systemctl enable docker.socket
if [[ -f /usr/lib/systemd/system/brew-setup.service ]]; then
  systemctl enable brew-setup.service
fi

# --- Signature policy --------------------------------------------------------
# With the project's cosign key in the image, `bootc switch` / rpm-ostree
# rebase to ostree-image-signed:docker://… refuse unsigned or tampered images.
key=$CTX/keys/cosign.pub
if [[ -s $key ]]; then
  install -Dm0644 "$key" /etc/pki/containers/atomarchy.pub
  cat >/etc/containers/registries.d/atomarchy.yaml <<EOF
docker:
  ${IMAGE_REGISTRY}/atomarchy:
    use-sigstore-attachments: true
  ${IMAGE_REGISTRY}/atomarchy-gaming:
    use-sigstore-attachments: true
EOF
  policy=/etc/containers/policy.json
  tmp=$(mktemp)
  jq --arg main "${IMAGE_REGISTRY}/atomarchy" --arg gaming "${IMAGE_REGISTRY}/atomarchy-gaming" '
    .transports.docker[$main] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/atomarchy.pub", "signedIdentity": {"type": "matchRepository"}}]
    | .transports.docker[$gaming] = .transports.docker[$main]' "$policy" >"$tmp"
  install -m 0644 "$tmp" "$policy"
  rm -f "$tmp"
else
  warn "keys/cosign.pub not found: the image will not enforce signatures"
fi

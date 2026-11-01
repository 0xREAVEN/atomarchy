# Atomarchy development tasks (same steps as the CI).
#
#   just build            build atomarchy (or: just build atomarchy-gaming)
#   just test             smoke tests in the built image
#   just boot-test        install to a virtual disk and boot it (needs KVM)
#   just lint             shellcheck + just formatting
#   just iso              installer ISO from a published image

registry := env("IMAGE_REGISTRY", "ghcr.io/0xreaven")
fedora := "44"

default:
    @just --list

# Build an image (target: atomarchy | atomarchy-gaming)
build target="atomarchy":
    sudo podman build --target {{ target }} --pull=newer \
        --build-arg IMAGE_REGISTRY={{ registry }} --build-arg IMAGE_TAG=dev \
        -t localhost/{{ target }}:build .

# Smoke tests inside a built image
test target="atomarchy":
    sudo podman run --rm --network=none -v ./tests:/tests:ro localhost/{{ target }}:build /tests/smoke.sh

# Install the image to a virtual disk and boot it in QEMU/KVM
boot-test target="atomarchy":
    sudo tests/boot-test.sh localhost/{{ target }}:build ./output/boot-{{ target }}

# Lint shell scripts and justfiles
lint:
    shellcheck --external-sources --source-path=SCRIPTDIR --source-path=. --severity=warning \
        $(find build_files tests iso .github/scripts -name '*.sh') \
        $(find system_files -path '*/libexec/atomarchy/*' -type f) \
        $(find system_files -path '*/share/atomarchy/bin/*' -type f)
    for f in $(find system_files -name '*.just') Justfile; do just --unstable --fmt --check --justfile "$f"; done

# Installer ISO for a published image (channel: stable | testing)
iso target="atomarchy" channel="stable":
    sudo podman pull {{ registry }}/{{ target }}:{{ channel }}
    sudo podman build --build-arg PAYLOAD_REF={{ registry }}/{{ target }}:{{ channel }} \
        --build-arg ENROLL_UBLUE_KEY={{ if target == "atomarchy-gaming" { "1" } else { "0" } }} \
        -t localhost/atomarchy-installer:latest iso/
    mkdir -p output
    sudo podman run --rm --privileged --security-opt label=type:unconfined_t \
        -v ./output:/output -v /var/lib/containers/storage:/var/lib/containers/storage \
        ghcr.io/osbuild/image-builder-cli:v88.0.0 build --output-dir /output \
        --bootc-ref localhost/atomarchy-installer:latest \
        --bootc-installer-payload-ref {{ registry }}/{{ target }}:{{ channel }} \
        --bootc-default-fs btrfs generic-iso

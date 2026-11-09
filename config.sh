#!/bin/bash
# Build configuration for the UDM-Pro Ubuntu image.

# Ubuntu release to build (must exist on ports.ubuntu.com)
SUITE="${SUITE:-noble}"

# Ubuntu base rootfs tarball (arm64). Fetched at build time if missing.
BASE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/${SUITE}/release"
BASE_TARBALL="${BASE_TARBALL:-ubuntu-base-24.04.5-base-arm64.tar.gz}"

# Image geometry: GPT, single ext4 root partition.
IMAGE_SIZE="${IMAGE_SIZE:-4G}"
ROOT_LABEL="udm-ubuntu"

# Package set installed into the image
PACKAGES_FILE="$(dirname "${BASH_SOURCE[0]}")/packages.list"

# Users:
#   root     -> random password, generated at build, emitted to build artifacts
#   ubuntu   -> password "ubuntu", member of sudo (standard cloud-image convention)
UBUNTU_PASSWORD="${UBUNTU_PASSWORD:-ubuntu}"

# Output directory for artifacts
OUT_DIR="${OUT_DIR:-out}"

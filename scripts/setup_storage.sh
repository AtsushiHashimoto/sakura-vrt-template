#!/bin/bash
# Configure storage for VRT research environment and start Docker.
# Run as root via systemd before docker.service.
#
# H100 (NVMe present):
#   NVMe p1 (1 GiB)  — dm-cache metadata
#   NVMe p2 (2 TiB)  — dm-cache cache for /workspace
#   NVMe p3 (rest)   — scratch: Docker data-root, HF/PyTorch caches
#
#   /workspace is backed by a sparse loopback file on the system disk
#   (/var/lib/vrt/workspace.img) and accelerated by dm-cache on NVMe.
#   Writethrough mode: system disk always holds current data.
#   NVMe loss on server stop = cold cache next boot, not data loss.
#
# V100 (no NVMe):
#   /workspace is a plain directory on the system disk.
#   HF/PyTorch caches go to /home/ubuntu/.cache/.

set -euo pipefail

NVME=/dev/nvme0n1
WORKSPACE_IMG=/var/lib/vrt/workspace.img
WORKSPACE_IMG_VSIZE=2T
WORKSPACE=/workspace
NVME_MOUNT=/mnt/nvme
DMNAME=vrt-workspace

log() { echo "[setup_storage] $*"; }

if mountpoint -q "${WORKSPACE}"; then
    log "Already mounted. Skipping."
    exit 0
fi

mkdir -p "${WORKSPACE}" /var/lib/vrt

# Attach a loopback device to the workspace sparse file.
# Creates and formats the file on first boot.
attach_workspace_img() {
    if [ ! -f "${WORKSPACE_IMG}" ]; then
        log "Creating workspace image (first boot)..."
        truncate -s "${WORKSPACE_IMG_VSIZE}" "${WORKSPACE_IMG}"
        local loop
        loop=$(losetup -f)
        losetup "${loop}" "${WORKSPACE_IMG}"
        mkfs.xfs -q "${loop}"
        losetup -d "${loop}"
    fi
    local loop
    loop=$(losetup -f)
    losetup "${loop}" "${WORKSPACE_IMG}"
    echo "${loop}"
}

if [ -b "${NVME}" ]; then
    # ── H100: dm-cache ───────────────────────────────────────────────────────

    log "NVMe detected (H100). Configuring dm-cache workspace."

    log "Partitioning NVMe..."
    sgdisk --zap-all "${NVME}" > /dev/null
    sgdisk -n 1:0:+1G "${NVME}" > /dev/null    # dm-cache metadata
    sgdisk -n 2:0:+2T "${NVME}" > /dev/null    # dm-cache cache
    sgdisk -n 3:0:0   "${NVME}" > /dev/null    # scratch
    udevadm settle

    modprobe dm_cache dm_cache_smq

    LOOP=$(attach_workspace_img)
    log "Workspace image attached as ${LOOP}."

    log "Creating dm-cache device (writethrough)..."
    ORIGIN_SECTORS=$(blockdev --getsz "${LOOP}")
    dmsetup create "${DMNAME}" \
        --table "0 ${ORIGIN_SECTORS} cache \
/dev/nvme0n1p1 /dev/nvme0n1p2 ${LOOP} \
512 1 writethrough smq 0"

    mount /dev/mapper/${DMNAME} "${WORKSPACE}"

    log "Formatting NVMe scratch partition..."
    mkfs.xfs -f -q /dev/nvme0n1p3
    mkdir -p "${NVME_MOUNT}"
    mount /dev/nvme0n1p3 "${NVME_MOUNT}"

    mkdir -p \
        "${NVME_MOUNT}/docker" \
        "${NVME_MOUNT}/.cache/huggingface" \
        "${NVME_MOUNT}/.cache/torch"
    chown -R ubuntu:ubuntu "${NVME_MOUNT}"

    # Point Docker to NVMe scratch
    cat > /etc/docker/daemon.json <<EOF
{"data-root": "${NVME_MOUNT}/docker"}
EOF

    tee /etc/environment > /dev/null <<EOF
HF_HOME=${NVME_MOUNT}/.cache/huggingface
TORCH_HOME=${NVME_MOUNT}/.cache/torch
EOF

else
    # ── V100: system disk only ───────────────────────────────────────────────

    log "No NVMe (V100). Using system disk for workspace."

    # Remove any stale NVMe-specific Docker config
    rm -f /etc/docker/daemon.json

    mkdir -p /home/ubuntu/.cache/huggingface /home/ubuntu/.cache/torch
    chown -R ubuntu:ubuntu /home/ubuntu/.cache

    tee /etc/environment > /dev/null <<EOF
HF_HOME=/home/ubuntu/.cache/huggingface
TORCH_HOME=/home/ubuntu/.cache/torch
EOF
fi

chown ubuntu:ubuntu "${WORKSPACE}"
mkdir -p "${WORKSPACE}/checkpoints" "${WORKSPACE}/results"
chown -R ubuntu:ubuntu "${WORKSPACE}"

log "Starting Docker..."
systemctl start docker

log "Done."
log "  ${WORKSPACE}    — workspace (persistent$([ -b "${NVME}" ] && echo ', dm-cache accelerated'))"
[ -b "${NVME}" ] && log "  ${NVME_MOUNT}  — NVMe scratch (Docker, HF/PyTorch caches)"

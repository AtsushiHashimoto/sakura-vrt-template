#!/bin/bash
# Cleanly tear down VRT storage before server shutdown.
# Run as root via systemd ExecStop.

set -euo pipefail

WORKSPACE=/workspace
NVME_MOUNT=/mnt/nvme
DMNAME=vrt-workspace
WORKSPACE_IMG=/var/lib/vrt/workspace.img

log() { echo "[shutdown_storage] $*"; }

log "Stopping Docker..."
systemctl stop docker || true

if mountpoint -q "${WORKSPACE}"; then
    log "Unmounting workspace..."
    umount "${WORKSPACE}"
fi

if dmsetup info "${DMNAME}" > /dev/null 2>&1; then
    log "Removing dm-cache device..."
    dmsetup remove "${DMNAME}"
fi

LOOP=$(losetup -j "${WORKSPACE_IMG}" 2>/dev/null | cut -d: -f1 || true)
if [ -n "${LOOP}" ]; then
    log "Detaching loopback ${LOOP}..."
    losetup -d "${LOOP}"
fi

if mountpoint -q "${NVME_MOUNT}"; then
    log "Unmounting NVMe scratch..."
    umount "${NVME_MOUNT}"
fi

log "Done."

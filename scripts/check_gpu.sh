#!/bin/bash
# Verify GPU, Docker GPU access, and storage are working correctly.

set -e

echo "=== Host GPU check ==="
nvidia-smi

echo ""
echo "=== Docker GPU check ==="
docker run --rm --gpus all \
    nvidia/cuda:12.0-base-ubuntu22.04 \
    nvidia-smi

echo ""
echo "=== Storage check ==="
echo "Workspace mount:"
mountpoint /workspace && df -h /workspace

echo ""
echo "NVMe scratch (H100 only):"
df -h /mnt/nvme 2>/dev/null || echo "  (no NVMe — V100 plan)"

echo ""
echo "dm-cache status (H100 only):"
dmsetup status vrt-workspace 2>/dev/null || echo "  (no dm-cache — V100 plan)"

echo ""
echo "All checks passed."

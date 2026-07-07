#!/usr/bin/env bash
# Build and push only the shipping image for linux/amd64, then verify the
# pushed manifest advertises linux/amd64 before disabling the runtime hotfix.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../techx-corp-platform"

[ -f .env.override ] || { echo "missing .env.override"; exit 1; }

set -a
. ./.env.override
set +a

IMAGE_REF="${IMAGE_NAME}:${DEMO_VERSION}-shipping"

echo ">> build + push shipping only for linux/amd64"
PLATFORMS="linux/amd64" TARGETS_OVERRIDE="shipping" bash "$HERE/build-push-images.sh"

echo ">> verify pushed manifest: $IMAGE_REF"
docker buildx imagetools inspect "$IMAGE_REF"

if ! docker buildx imagetools inspect "$IMAGE_REF" | grep -q "linux/amd64"; then
  echo "shipping image is missing linux/amd64 in the pushed manifest"
  exit 1
fi

echo "done -> shipping image is ready for linux/amd64"

#!/usr/bin/env bash
# Build app images multi-arch (amd64+arm64) from source and push them to the
# registry configured in techx-corp-platform/.env.override.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../techx-corp-platform"

[ -f .env.override ] || { echo "missing .env.override"; exit 1; }
echo ">> IMAGE_NAME: $(grep IMAGE_NAME .env.override)"

PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

DEFAULT_TARGETS=(
  accounting
  ad
  cart
  checkout
  currency
  email
  flagd-ui
  fraud-detection
  frontend
  frontend-proxy
  image-provider
  kafka
  llm
  load-generator
  payment
  product-catalog
  product-reviews
  quote
  recommendation
  shipping
)

if [ -n "${TARGETS_OVERRIDE:-}" ]; then
  # shellcheck disable=SC2206
  TARGETS=(${TARGETS_OVERRIDE})
else
  TARGETS=("${DEFAULT_TARGETS[@]}")
fi

# Smoke-build one Go service first to catch environment issues early.
if [[ " ${TARGETS[*]} " == *" checkout "* ]]; then
  echo ">> smoke build checkout (single-arch, no push)"
  docker compose build checkout
fi

if [[ "$PLATFORMS" == "linux/amd64" ]]; then
  echo ">> use default buildx builder for single-platform linux/amd64 build"
  docker buildx use default
else
  echo ">> recreate dedicated multi-platform builder"
  docker buildx rm techx-corp-builder >/dev/null 2>&1 || true
  make create-multiplatform-builder
fi

# Public observability dependencies such as opensearch are not pushed to the
# team registry, so we explicitly build/push only the app targets here.
echo ">> build + push app targets for platforms: $PLATFORMS"
set -a
. ./.env.override
set +a
docker buildx bake -f docker-compose.yml "${TARGETS[@]}" \
  --push \
  --set "*.platform=${PLATFORMS}"

echo "done -> app images pushed to the registry from IMAGE_NAME"

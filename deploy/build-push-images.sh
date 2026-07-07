#!/usr/bin/env bash
# Build app images multi-arch (amd64+arm64) from source and push them to the
# registry configured in techx-corp-platform/.env.override.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../techx-corp-platform"

[ -f .env.override ] || { echo "missing .env.override"; exit 1; }
echo ">> IMAGE_NAME: $(grep IMAGE_NAME .env.override)"

TARGETS=(
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

# Smoke-build one Go service first to catch environment issues early.
echo ">> smoke build checkout (single-arch, no push)"
docker compose build checkout

# Builder multi-arch (one-time)
make create-multiplatform-builder || true

# Public observability dependencies such as opensearch are not pushed to the
# team registry, so we explicitly build/push only the app targets here.
echo ">> multi-arch build + push app targets (amd64+arm64)"
set -a
. ./.env.override
set +a
docker buildx bake -f docker-compose.yml "${TARGETS[@]}" \
  --push \
  --set "*.platform=linux/amd64,linux/arm64"

echo "done -> app images pushed to the registry from IMAGE_NAME"

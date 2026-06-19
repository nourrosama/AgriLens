#!/usr/bin/env bash
# Run this on the Linux staging server to deploy/update AgriLens.
#
# Usage:
#   ./scripts/deploy.sh
#   ./scripts/deploy.sh --skip-models
#   ./scripts/deploy.sh --service backend

set -euo pipefail

SKIP_MODELS=false
SERVICE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-models)
            SKIP_MODELS=true
            shift
            ;;
        --service)
            SERVICE="${2:-}"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 2
            ;;
    esac
done

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

NGINX_PORT="${NGINX_HTTP_PORT:-8080}"

echo "============================================"
echo "AgriLens deploy - $(date '+%Y-%m-%d %H:%M:%S')"
echo "Directory: $PROJECT_DIR"
echo "============================================"

if [[ -d ".git" ]]; then
    echo "[1/5] Pulling latest code..."
    git pull origin main
else
    echo "[1/5] Not a git repo; skipping pull"
fi

if [[ "$SKIP_MODELS" == "false" ]]; then
    echo "[2/5] Checking local model cache..."
    mkdir -p models
    MODELS_COUNT=$(find models -maxdepth 1 \( -name '*.pth' -o -name '*.pt' -o -name '*.keras' -o -name '*.json' \) | wc -l)
    if [[ "$MODELS_COUNT" -ge 10 ]]; then
        echo "      Models already present ($MODELS_COUNT files); container startup will skip existing files."
    else
        echo "      Model cache is incomplete ($MODELS_COUNT files); detection-service will download from S3 on startup."
    fi
else
    echo "[2/5] Skipping model check (--skip-models)"
fi

echo "[3/5] Building Docker images..."
if [[ -n "$SERVICE" ]]; then
    docker compose build "$SERVICE"
else
    docker compose build backend detection-service notification-service
fi

echo "[4/5] Starting services..."
if [[ -n "$SERVICE" ]]; then
    docker compose up -d "$SERVICE"
else
    docker compose up -d
fi

echo "[5/5] Waiting for gateway health check..."
for i in $(seq 1 12); do
    sleep 5
    STATUS=$(curl -sf "http://localhost:${NGINX_PORT}/api/health" 2>/dev/null \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null \
        || echo "unreachable")
    echo "      Attempt $i: $STATUS"
    if [[ "$STATUS" == "ok" || "$STATUS" == "healthy" ]]; then
        break
    fi
done

docker compose ps
echo "Deploy complete."

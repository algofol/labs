#!/usr/bin/env bash

set -e

FLOCI_CONTAINER="floci"
DASH_CONTAINER="floci-dash"
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

echo "======================================"
echo " Starting Floci + Floci Dash"
echo "======================================"

# Start Floci if it isn't already running
if ! docker ps --format '{{.Names}}' | grep -qx "$FLOCI_CONTAINER"; then
    echo "[1/3] Starting Floci..."
    
    docker rm -f "$FLOCI_CONTAINER"    
    #docker start "$FLOCI_CONTAINER" 2>/dev/null || \
    docker run -d \
        --name "$FLOCI_CONTAINER" \
        -e FLOCI_STORAGE_MODE=persistent \
        -e FLOCI_STORAGE_PERSISTENT_PATH=/app/data \
        -p 4566:4566 \
        -v /opt/floci:/app/data \
        -v /var/run/docker.sock:/var/run/docker.sock \
        floci/floci:latest
else
    echo "[1/3] Floci already running."
fi

# Wait for Floci
echo "[2/3] Waiting for Floci..."

until curl -sf http://127.0.0.1:4566/_floci/health >/dev/null 2>&1; do
    sleep 1
done

echo "      Floci is ready."

# Remove old dashboard container if necessary
docker rm -f "$DASH_CONTAINER" >/dev/null 2>&1 || true

echo "[3/3] Starting Floci Dash..."

docker run -d \
    --name "$DASH_CONTAINER" \
    --network host \
    -e FLOCI_URL=http://127.0.0.1:4566 \
    ghcr.io/ofsazib/floci-dash:latest

echo
echo "======================================"
echo " Floci:     http://127.0.0.1:4566"
echo " Dashboard: http://127.0.0.1:3000"
echo "======================================"

# Wait for dashboard
until curl -sf http://127.0.0.1:3000/api/healthz >/dev/null 2>&1; do
    sleep 1
done

echo "Dashboard is ready."

# Open browser
if command -v xdg-open >/dev/null 2>&1; then
    xdg-open http://127.0.0.1:3000 >/dev/null 2>&1 &
elif command -v firefox >/dev/null 2>&1; then
    firefox http://127.0.0.1:3000 >/dev/null 2>&1 &
fi

echo
echo "Floci Dash is running."

echo "Patching floci-dash"
/home/manager/Desktop/github_repos/labs/AWS/floci/patch_floci_dash.sh
echo "Floci Dash is patched"
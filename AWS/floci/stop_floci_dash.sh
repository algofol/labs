#!/usr/bin/env bash

set -e

FLOCI_CONTAINER="floci"
DASH_CONTAINER="floci-dash"

echo "======================================"
echo " Stopping Floci + Floci Dash"
echo "======================================"

docker stop "$FLOCI_CONTAINER"
docker stop "$DASH_CONTAINER"

echo "Floci + Floci Dash is stopped."


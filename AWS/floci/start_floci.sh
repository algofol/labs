FLOCI_DATA_DIR="/opt/floci-data"

if [ ! -d "$FLOCI_DATA_DIR" ]; then
  echo "Creating Floci data directory: $FLOCI_DATA_DIR"
  sudo mkdir -p "$FLOCI_DATA_DIR" || { echo "Couldn't create $FLOCI_DATA_DIR"; return 1 2>/dev/null || exit 1; }
fi

# Run Floci on persistent mode
sudo floci start --persist "$FLOCI_DATA_DIR"

# export AWS variables
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

sudo floci status


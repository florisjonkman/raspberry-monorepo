#!/bin/bash
# Setup SOPS with age encryption

set -e

SOPS_AGE_DIR="${HOME}/.config/sops/age"
SOPS_AGE_KEY="${SOPS_AGE_DIR}/keys.txt"

echo "Setting up SOPS with age encryption..."

# Check if age is installed
if ! command -v age-keygen &> /dev/null; then
    echo "Error: age is not installed."
    echo "Install with: brew install age"
    exit 1
fi

# Check if SOPS is installed
if ! command -v sops &> /dev/null; then
    echo "Error: sops is not installed."
    echo "Install with: brew install sops"
    exit 1
fi

# Create directory if it doesn't exist
mkdir -p "${SOPS_AGE_DIR}"

# Generate key if it doesn't exist
if [ -f "${SOPS_AGE_KEY}" ]; then
    echo "Age key already exists at ${SOPS_AGE_KEY}"
else
    echo "Generating new age key..."
    age-keygen -o "${SOPS_AGE_KEY}"
    chmod 600 "${SOPS_AGE_KEY}"
    echo "Key generated at ${SOPS_AGE_KEY}"
fi

# Extract public key
PUBLIC_KEY=$(grep "public key:" "${SOPS_AGE_KEY}" | cut -d: -f2 | tr -d ' ')

echo ""
echo "Your public key is:"
echo "${PUBLIC_KEY}"
echo ""
echo "Update .sops.yaml with this public key:"
echo ""
echo "creation_rules:"
echo "  - path_regex: \\.enc\\.yaml\$"
echo "    age: ${PUBLIC_KEY}"
echo ""
echo "Done!"

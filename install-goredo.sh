#!/bin/bash
set -euo pipefail

# goredo installation script with PGP verification
# Version: 2.6.5
# PGP Key: 7531BB84FAF0BF35960C63B93A528DDE952C7E93
# 
# This script downloads and verifies goredo using:
# - Meta4 file from: http://www.goredo.cypherpunks.su/download/goredo-2.6.5.tar.zst.meta4
# - PGP signature verification with key: 7531BB84FAF0BF35960C63B93A528DDE952C7E93
#
# Requirements:
# - curl, gpg, zstd, tar, go
# - Internet access to www.goredo.cypherpunks.su and keys.openpgp.org

GOREDO_VERSION="2.6.5"
GOREDO_BASE_URL="http://www.goredo.cypherpunks.su/download"
GOREDO_TARBALL="goredo-${GOREDO_VERSION}.tar.zst"
GOREDO_META4="${GOREDO_TARBALL}.meta4"
PGP_KEY="7531BB84FAF0BF35960C63B93A528DDE952C7E93"

echo "Installing goredo ${GOREDO_VERSION}..."

# Check requirements
for cmd in curl gpg zstd tar go; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: Required command '$cmd' not found"
        exit 1
    fi
done

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$TMP_DIR"

# Test connectivity to the download server
echo "Testing connectivity to ${GOREDO_BASE_URL}..."
if ! curl -fsSL --connect-timeout 10 "${GOREDO_BASE_URL}/" -o /dev/null 2>&1; then
    echo "ERROR: Cannot connect to ${GOREDO_BASE_URL}"
    echo "This may be due to network restrictions or firewall rules."
    echo "Please ensure access to www.goredo.cypherpunks.su is allowed."
    exit 1
fi

# Download meta4 file
echo "Downloading ${GOREDO_META4}..."
if ! curl -fsSL "${GOREDO_BASE_URL}/${GOREDO_META4}" -o "${GOREDO_META4}"; then
    echo "ERROR: Failed to download ${GOREDO_META4}"
    exit 1
fi

# Import PGP key
echo "Importing PGP key ${PGP_KEY}..."
gpg --keyserver hkps://keys.openpgp.org --recv-keys "${PGP_KEY}" 2>&1 | grep -v "^gpg: " || true

# Extract download URL from meta4 file
echo "Parsing meta4 file for download URL..."
DOWNLOAD_URL=$(grep -oP 'https?://[^"]+\.tar\.zst' "${GOREDO_META4}" | head -1)
if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not extract download URL from meta4 file"
    exit 1
fi

# Download signature file
echo "Downloading signature..."
curl -fsSL "${DOWNLOAD_URL}.asc" -o "${GOREDO_TARBALL}.asc" || {
    echo "WARNING: Could not download signature file, trying alternative location..."
    curl -fsSL "${GOREDO_BASE_URL}/${GOREDO_TARBALL}.asc" -o "${GOREDO_TARBALL}.asc"
}

# Download tarball
echo "Downloading ${GOREDO_TARBALL}..."
curl -fsSL "${DOWNLOAD_URL}" -o "${GOREDO_TARBALL}"

# Verify PGP signature
echo "Verifying PGP signature..."
gpg --verify "${GOREDO_TARBALL}.asc" "${GOREDO_TARBALL}" 2>&1 | grep -q "Good signature" || {
    echo "ERROR: PGP signature verification failed!"
    exit 1
}

echo "PGP signature verified successfully!"

# Extract and install
echo "Extracting goredo..."
zstd -d "${GOREDO_TARBALL}" -c | tar -xf -

cd "goredo-${GOREDO_VERSION}"

# Build and install goredo
echo "Building goredo..."
GOPATH="${GOPATH:-$HOME/go}"
export GOPATH
mkdir -p "${GOPATH}/bin"

# Build goredo-sources first if needed
if [ -f "goredo-sources.go" ]; then
    go build -o "${GOPATH}/bin/goredo-sources" goredo-sources.go
fi

# Build main goredo
go build -o "${GOPATH}/bin/goredo"

# Build additional tools
for tool in goredo-*.go; do
    if [ "$tool" != "goredo-sources.go" ] && [ -f "$tool" ]; then
        toolname=$(basename "$tool" .go)
        go build -o "${GOPATH}/bin/${toolname}" "$tool"
    fi
done

echo "goredo ${GOREDO_VERSION} installed successfully to ${GOPATH}/bin/"
echo "Make sure ${GOPATH}/bin is in your PATH"

# Verify installation
"${GOPATH}/bin/goredo" -version

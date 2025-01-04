#!/usr/bin/env zsh
set -e  # Exit on any error

# Enable safe mode
set -euo pipefail

# Default installation prefix
PREFIX="${HOME}/.local"
SCRIPT_DIR="${0:A:h}"  # Get absolute path to script directory

# Initialize flags
FORCE=0
USE_FALLBACK=0

usage() {
    cat << EOF
Usage: $0 [options]

Build and install pilot-link utilities for Apple Silicon

Options:
    -h, --help          Show this help message
    --prefix=PATH       Installation prefix (default: ${HOME}/.local)
    --force            Force rebuild and reapply patches
    --use-fallback     Use local archive instead of git clone
    --clean            Remove source directory and exit

Examples:
    $0 --prefix=/usr/local
    $0 --use-fallback
    $0 --clean
EOF
}

# Track source directory name
SOURCE_DIR="pilot-link"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            # Ensure prefix is absolute path
            case "$PREFIX" in
                /*) ;;
                *) PREFIX="$PWD/$PREFIX" ;;
            esac
            ;;
        --force)
            FORCE=1
            ;;
        --use-fallback)
            USE_FALLBACK=1
            ;;
        --clean)
            if [[ -d "$SOURCE_DIR" ]] && [[ "$SOURCE_DIR" != "/" ]]; then
                echo "Removing $SOURCE_DIR directory..."
                rm -rf "./$SOURCE_DIR"
            fi
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

# Check if pilot-link exists and patches have been applied
check_patch_status() {
    local patch_file="$1"
    local patch_name=$(basename "$patch_file")
    if patch -R -p1 -s -f --dry-run < "$patch_file" >/dev/null 2>&1; then
        echo "Patch $patch_name has already been applied"
        return 0
    else
        echo "Patch $patch_name hasn't been applied"
        return 1
    fi
}

# Install dependencies
echo "Installing dependencies..."
if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is required but not installed" >&2
    exit 1
fi
brew install autoconf automake pkg-config libusb libtool gcc

# Get pilot-link source code
echo "Checking for source code..."
if [[ ! -d "$SOURCE_DIR" ]]; then
    if [[ -n "$USE_FALLBACK" ]] || ! git clone --depth=1 https://github.com/desrod/pilot-link.git 2>/dev/null; then
        echo "Git clone failed, falling back to local archive..."
        if [[ ! -d "fallback" ]]; then
            echo "Error: fallback directory not found" >&2
            exit 1
        fi
        
        # Find the first .tar.zst file in fallback directory
        archive=$(find "$SCRIPT_DIR/fallback" -maxdepth 1 -name "*.tar.zst" -type f | head -n 1)
        if [[ -z "$archive" ]]; then
            echo "Error: No .tar.zst archive found in fallback directory" >&2
            exit 1
        fi
        
        # Validate archive path
        if [[ ! "$archive" =~ ^[[:alnum:]/_.-]+$ ]]; then
            echo "Error: Invalid characters in archive path" >&2
            exit 1
        fi
        
        # Extract directory name from archive name (remove .tar.zst extension)
        SOURCE_DIR=${${archive:t}%.tar.zst}
        if [[ -z "$SOURCE_DIR" ]] || [[ "$SOURCE_DIR" == "/" ]]; then
            echo "Error: Invalid source directory name" >&2
            exit 1
        fi
        
        echo "Extracting $archive..."
        # Create temp directory for extraction
        TEMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TEMP_DIR"' EXIT
        
        # Extract to temp directory first
        if ! zstd -dc "$archive" | tar xf - -C "$TEMP_DIR"; then
            echo "Error: Archive extraction failed" >&2
            exit 1
        fi
        
        # Move to final location
        mv "$TEMP_DIR"/* ./ || {
            echo "Error: Failed to move extracted files" >&2
            exit 1
        }
    fi
elif [[ -n "$FORCE" ]]; then
    echo "Force rebuild requested, cleaning source directory..."
    cd "$SOURCE_DIR"
    git clean -fdx
    git reset --hard
    cd ..
fi

cd "$SOURCE_DIR"

# Copy config files if they don't exist or force is enabled
echo "Checking config files..."
if [[ ! -f "config.guess" ]] || [[ ! -f "config.sub" ]] || [[ -n "$FORCE" ]]; then
    echo "Copying config files..."
    cp "$SCRIPT_DIR/patches/config.guess" .
    cp "$SCRIPT_DIR/patches/config.sub" .
fi

# Apply patches if needed
echo "Checking patches..."
for patch in "$SCRIPT_DIR"/patches/pilot-link-png14.patch "$SCRIPT_DIR"/patches/configure-checks.patch "$SCRIPT_DIR"/patches/format-string-literals.patch; do
    if [[ -n "$FORCE" ]] || ! check_patch_status "$patch"; then
        echo "Applying $patch..."
        patch -p1 < "$patch"
    fi
done

# Run autogen
echo "Running autogen..."
./autogen.sh --prefix="$PREFIX" --enable-conduits --enable-libusb

# Build using all CPUs
echo "Building..."
make -j$(sysctl -n hw.ncpu)

if [[ -w "$PREFIX" ]]; then
    echo "Installing..."
    # If prefix is writable, no need for sudo
    make install
else
    echo "Requires sudo to install here."
    # Use sudo only if needed
    sudo make install
fi

echo "Build complete! pilot-link has been installed to $PREFIX"

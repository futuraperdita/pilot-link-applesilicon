# pilot-link for Apple Silicon

This repository [ports the AUR build PKGBUILD for `pilot-link-git`](https://aur.archlinux.org/packages/pilot-link-git) to allow building of the `pilot-link` suite of Palm OS tools on Apple Silicon Macs. Connect your ancient Palm to your Mac like it's 2001 again!

While this will try to pull the latest git from [desrod/pilot-link](https://github.com/desrod/pilot-link), it will fall back to a local archive if the git clone fails. This is to allow for building even if the original source disappears, since these legacy utilities have a tendency to be abandoned and/or vanish.

## Prerequisites

- macOS running on Apple Silicon
- [Homebrew](https://brew.io) package manager
- Command line tools (will be installed by Homebrew if missing)

## Usage

```bash
./build.sh [options]
```

### Options

- `-h, --help`: Show help message
- `--prefix=PATH`: Installation prefix (default: $HOME/.local)
- `--force`: Force rebuild and reapply patches
- `--use-fallback`: Use local archive (a snapshot of [desrod/pilot-link](https://github.com/desrod/pilot-link)) instead of git clone
- `--clean`: Remove source directory and exit

### Examples

```bash
# Default build
./build.sh

# Install to /usr/local
./build.sh --prefix=/usr/local

# Use local archive instead of git
./build.sh --use-fallback

# Force rebuild
./build.sh --force

# Clean build directory
./build.sh --clean
```

## Build Process

1. Installs required dependencies via Homebrew
2. Clones pilot-link repository (or uses local archive)
3. Applies necessary patches for Apple Silicon compatibility
4. Configures build with provided prefix
5. Compiles using all available CPU cores
6. Installs to specified prefix (uses sudo if needed)

## Directory Structure

- `patches/`: Contains required patches for Apple Silicon compatibility
- `fallback/`: Contains backup source archive if GitHub is unavailable
- `build.sh`: Main build script

## Troubleshooting

If the build fails:

1. Try cleaning the build directory: `./build.sh --clean`
2. Run with force flag: `./build.sh --force`
3. If GitHub is unavailable, use: `./build.sh --use-fallback`

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

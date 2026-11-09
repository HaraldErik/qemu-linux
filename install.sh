#!/usr/bin/env bash
# qemu-linux installer: builds the Power Mac G3 / G4 / G5 QEMU machines on
# Linux (Arch, Fedora, Debian/Ubuntu and their relatives) and installs the
# `qemu-mac` helper that creates and starts virtual Macs.
#
#   curl -fsSL https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom/install.sh | bash -s -- --machine all
#
# Run with --help for all options.

set -euo pipefail

FORK_REPO="https://github.com/HaraldErik/qemu-linux.git"
UPSTREAM_REPO="https://github.com/cat7/qemu.git"
RAW_BASE="https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom"
RELEASES_API="https://api.github.com/repos/cat7/qemu/releases?per_page=50"

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/qemu-linux"
BINDIR="$HOME/.local/bin"
MACHINES=""
INSTALL_DEPS=1
KEEP_SOURCE=0
UNINSTALL=0
PURGE=0
ASSUME_YES=0
JOBS="$(nproc 2>/dev/null || echo 2)"

if [ -t 1 ]; then
    B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=; R=; G=; Y=; C=; N=
fi
say()  { printf '%s==>%s %s\n' "$C$B" "$N" "$*"; }
ok()   { printf '%s ✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s !%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%s ✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

usage() {
    cat <<EOF
qemu-linux installer -- Power Mac G3/G4/G5 emulation for Linux

Usage: install.sh [options]

  -m, --machine LIST   Machines to build: g3, g4, g5, all, or a list like g3,g5.
                       Asks when run in a terminal; defaults to g3 otherwise.
  -p, --prefix DIR     Install location (default: $PREFIX)
  -b, --bindir DIR     Where the qemu-mac command goes (default: $BINDIR)
  -j, --jobs N         Parallel compile jobs (default: $JOBS)
      --no-deps        Do not install build dependencies with the package manager
      --keep-source    Keep the source and build trees (faster rebuilds)
  -y, --yes            Do not ask questions
      --uninstall      Remove the emulators and qemu-mac (your VMs are kept)
      --purge          With --uninstall: also delete all VMs
  -h, --help           Show this help

Supported: Arch Linux (Manjaro, EndeavourOS, CachyOS, ...), Fedora (Nobara,
RHEL-likes with EPEL/CRB), Debian (Ubuntu, Mint, Pop!_OS, ...).
Run it again at any time to update.
EOF
}

ask() { # ask "question" default -> echo answer
    local q="$1" def="$2" a=""
    if [ "$ASSUME_YES" = 1 ] || ! { [ -r /dev/tty ] && : </dev/tty; } 2>/dev/null; then
        echo "$def"; return
    fi
    printf '%s?%s %s [%s] ' "$B" "$N" "$q" "$def" >/dev/tty
    read -r a </dev/tty || true
    echo "${a:-$def}"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -m|--machine) MACHINES="${2:?--machine needs a value}"; shift ;;
            --machine=*)  MACHINES="${1#*=}" ;;
            -p|--prefix)  PREFIX="${2:?}"; shift ;;
            --prefix=*)   PREFIX="${1#*=}" ;;
            -b|--bindir)  BINDIR="${2:?}"; shift ;;
            --bindir=*)   BINDIR="${1#*=}" ;;
            -j|--jobs)    JOBS="${2:?}"; shift ;;
            -j*)          JOBS="${1#-j}" ;;
            --jobs=*)     JOBS="${1#*=}" ;;
            --no-deps)    INSTALL_DEPS=0 ;;
            --keep-source) KEEP_SOURCE=1 ;;
            -y|--yes)     ASSUME_YES=1 ;;
            --uninstall)  UNINSTALL=1 ;;
            --purge)      PURGE=1 ;;
            -h|--help)    usage; exit 0 ;;
            *) die "Unknown option: $1 (see --help)" ;;
        esac
        shift
    done
}

# --------------------------------------------------------------------------
# Distribution detection and dependencies
# --------------------------------------------------------------------------

SUDO=""
detect_family() {
    [ -r /etc/os-release ] || die "Cannot read /etc/os-release; unknown distribution."
    # shellcheck disable=SC1091
    . /etc/os-release
    local ids=" ${ID:-} ${ID_LIKE:-} "
    case "$ids" in
        *" arch "*|*" archlinux "*)               FAMILY=arch ;;
        *" fedora "*|*" rhel "*|*" centos "*)     FAMILY=fedora ;;
        *" debian "*|*" ubuntu "*)                FAMILY=debian ;;
        *) FAMILY=unknown ;;
    esac
    DISTRO_NAME="${PRETTY_NAME:-${ID:-unknown}}"
}

install_deps() {
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null || die "sudo is needed to install packages (or use --no-deps)."
        SUDO="sudo"
    fi
    say "Installing build dependencies for $DISTRO_NAME ($FAMILY)"
    case "$FAMILY" in
        arch)
            $SUDO pacman -S --needed --noconfirm \
                base-devel git python ninja pkgconf glib2 pixman libslirp dtc \
                gtk3 sdl2 libepoxy mesa libpulse alsa-lib pipewire \
                zlib zstd bzip2 curl unzip flex bison
            ;;
        fedora)
            $SUDO dnf install -y \
                gcc gcc-c++ make git python3 ninja-build pkgconf-pkg-config \
                glib2-devel pixman-devel libslirp-devel libfdt-devel \
                gtk3-devel SDL2-devel libepoxy-devel mesa-libgbm-devel \
                pulseaudio-libs-devel alsa-lib-devel pipewire-devel \
                zlib-devel libzstd-devel bzip2 curl unzip flex bison findutils
            ;;
        debian)
            $SUDO apt-get update
            DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y \
                build-essential git python3 python3-venv ninja-build pkg-config \
                libglib2.0-dev libpixman-1-dev libslirp-dev libfdt-dev \
                libgtk-3-dev libsdl2-dev libepoxy-dev libgbm-dev \
                libpulse-dev libasound2-dev libpipewire-0.3-dev \
                zlib1g-dev libzstd-dev bzip2 curl unzip flex bison ca-certificates
            ;;
        *)
            warn "Unsupported distribution: $DISTRO_NAME."
            warn "Install by hand: a C compiler, git, python3 (with venv), ninja, pkg-config,"
            warn "glib2, pixman, libslirp, libfdt, gtk3, SDL2, libepoxy, pulseaudio/alsa/pipewire"
            warn "development packages, curl and unzip. Then run again with --no-deps."
            die "Stopping."
            ;;
    esac
    ok "Dependencies installed"
}

check_tools() {
    local t missing=""
    for t in git make cc python3 ninja pkg-config curl unzip; do
        command -v "$t" >/dev/null || missing="$missing $t"
    done
    [ -z "$missing" ] || die "Missing tools:$missing (run without --no-deps, or install them)."
    python3 -c 'import venv, ensurepip' 2>/dev/null \
        || die "python3 venv/ensurepip is missing (Debian/Ubuntu: apt install python3-venv)."
}

# --------------------------------------------------------------------------
# Machines
# --------------------------------------------------------------------------

machine_branch() { case "$1" in g3) echo G3-rom ;; g4) echo G4-openbios ;; g5) echo G5-openbios ;; esac; }
machine_target() { case "$1" in g5) echo ppc64-softmmu ;; *) echo ppc-softmmu ;; esac; }
machine_binary() { case "$1" in g5) echo qemu-system-ppc64 ;; *) echo qemu-system-ppc ;; esac; }
machine_title()  {
    case "$1" in
        g3) echo "Beige Power Mac G3 (Apple ROM, Mac OS 8-9.2, OS X 10.0-10.2)" ;;
        g4) echo "Power Mac G4 (OpenBIOS, Mac OS 9.2, OS X 10.0-10.5)" ;;
        g5) echo "Power Mac G5 (OpenBIOS, OS X 10.3.9-10.5)" ;;
    esac
}

choose_machines() {
    if [ -z "$MACHINES" ]; then
        if [ "$ASSUME_YES" = 0 ] && { : </dev/tty; } 2>/dev/null; then
            {
                echo
                echo "${B}Which machines should be built?${N} (each takes a few minutes)"
                echo "  g3   $(machine_title g3)"
                echo "  g4   $(machine_title g4)"
                echo "  g5   $(machine_title g5)"
                echo "  all  all three"
            } >/dev/tty
            MACHINES="$(ask "Machines (e.g. g4 or g3,g5)" g4)"
        else
            MACHINES=g3
        fi
    fi
    MACHINES="$(echo "$MACHINES" | tr 'A-Z,' 'a-z ')"
    [ "$MACHINES" = all ] && MACHINES="g3 g4 g5"
    local m
    for m in $MACHINES; do
        case "$m" in g3|g4|g5) ;; *) die "Unknown machine '$m' (use g3, g4, g5 or all)." ;; esac
    done
}

# The fork may not carry every branch; fall back to cat7/qemu, where they live.
source_repo() {
    local branch="$1"
    if git ls-remote --exit-code --heads "$FORK_REPO" "$branch" >/dev/null 2>&1; then
        echo "$FORK_REPO"
    else
        echo "$UPSTREAM_REPO"
    fi
}

build_machine() {
    local m="$1" branch target bin repo src dest
    branch="$(machine_branch "$m")"
    target="$(machine_target "$m")"
    bin="$(machine_binary "$m")"
    repo="$(source_repo "$branch")"
    src="$PREFIX/src/$m"
    dest="$PREFIX/$m"

    say "Building $(machine_title "$m")"
    echo "    source: $repo ($branch)"

    mkdir -p "$PREFIX/src"
    if [ -d "$src/.git" ]; then
        git -C "$src" fetch --depth 1 origin "$branch"
        git -C "$src" reset --hard FETCH_HEAD
    else
        rm -rf "$src"
        git clone --depth 1 --branch "$branch" "$repo" "$src"
    fi

    mkdir -p "$src/build"
    (
        cd "$src/build"
        ../configure \
            --prefix="$dest" \
            --target-list="$target" \
            --enable-slirp --enable-gtk --enable-sdl \
            --disable-docs --disable-werror --disable-guest-agent \
            --disable-xen --disable-vnc-sasl
        make -j"$JOBS"
        rm -rf "$dest"
        make install
    )
    [ -x "$dest/bin/$bin" ] || die "Build finished but $dest/bin/$bin is missing."
    git -C "$src" rev-parse --short HEAD > "$dest/.commit"
    echo "$repo $branch" > "$dest/.source"
    ok "$bin installed to $dest/bin"

    if [ "$m" != g3 ]; then
        fetch_openbios "$m" "$branch" "$dest"
    fi
    if [ "$KEEP_SOURCE" = 0 ]; then
        rm -rf "$src"
    fi
}

# G4/G5 boot OpenBIOS from the matching cat7/openbios branch. Its ppc cross
# build needs a PowerPC toolchain, so take the prebuilt (platform-independent)
# openbios-qemu.elf from the newest release zip of that machine instead.
fetch_openbios() {
    local m="$1" branch="$2" dest="$3" tmp url fw="$3/share/qemu-linux"
    mkdir -p "$fw"
    tmp="$(mktemp -d)"
    say "Downloading OpenBIOS for $m"
    url="$(curl -fsSL "$RELEASES_API" | python3 -c '
import json, sys
branch = sys.argv[1]
for rel in json.load(sys.stdin):
    if not rel["tag_name"].startswith(branch):
        continue
    for a in rel["assets"]:
        if a["name"].endswith(".zip"):
            print(a["browser_download_url"]); sys.exit(0)
' "$branch")" || true
    if [ -z "$url" ]; then
        rm -rf "$tmp"
        warn "Could not find a $branch release; get openbios-qemu.elf yourself and put it in $fw/"
        return
    fi
    curl -fL --progress-bar -o "$tmp/rel.zip" "$url"
    unzip -q -j -o "$tmp/rel.zip" '*/openbios-qemu.elf' -d "$fw"
    unzip -q -j -o "$tmp/rel.zip" '*/osx9p-*.iso' -d "$fw" 2>/dev/null || true
    rm -rf "$tmp"
    [ -s "$fw/openbios-qemu.elf" ] || die "openbios-qemu.elf not found in $url"
    ok "OpenBIOS: $fw/openbios-qemu.elf"
}

install_launcher() {
    local here="" tool="$BINDIR/qemu-mac"
    mkdir -p "$BINDIR"
    # Only trust a local copy when run as a file (not piped from curl).
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$here" ] && [ -f "$here/linux/qemu-mac" ]; then
        cp "$here/linux/qemu-mac" "$tool.tmp"
    else
        curl -fsSL -o "$tool.tmp" "$RAW_BASE/linux/qemu-mac"
    fi
    # Bake the install prefix into the launcher.
    sed -i "s|^QEMU_LINUX_PREFIX_DEFAULT=.*|QEMU_LINUX_PREFIX_DEFAULT=\"$PREFIX\"|" "$tool.tmp"
    chmod +x "$tool.tmp"
    mv "$tool.tmp" "$tool"
    ok "qemu-mac installed to $tool"
    case ":$PATH:" in
        *":$BINDIR:"*) ;;
        *) warn "$BINDIR is not in your PATH. Add this to your shell config:"
           warn "    export PATH=\"$BINDIR:\$PATH\"" ;;
    esac
}

uninstall() {
    say "Removing qemu-linux"
    local m
    for m in g3 g4 g5; do rm -rf "${PREFIX:?}/$m"; done
    rm -rf "${PREFIX:?}/src" "$BINDIR/qemu-mac"
    if [ "$PURGE" = 1 ]; then
        rm -rf "${PREFIX:?}/vms"
        rmdir "$PREFIX" 2>/dev/null || true
        ok "Removed everything, including VMs"
    else
        ok "Removed. Your VMs are still in $PREFIX/vms (use --uninstall --purge to delete them)."
    fi
}

main() {
    parse_args "$@"
    if [ "$UNINSTALL" = 1 ]; then uninstall; exit 0; fi
    [ "$(id -u)" -ne 0 ] || warn "Running as root: everything goes into root's home. Run as your user instead."
    [ "$(uname -s)" = Linux ] || die "This installer is for Linux. See the README for macOS and Windows builds."

    detect_family
    echo "${B}qemu-linux${N} -- Power Mac emulation for Linux"
    echo "    system:  $DISTRO_NAME"
    echo "    install: $PREFIX"
    choose_machines
    echo "    machines: $MACHINES"

    [ "$INSTALL_DEPS" = 1 ] && install_deps
    check_tools

    local m start=$SECONDS
    for m in $MACHINES; do build_machine "$m"; done
    rmdir "$PREFIX/src" 2>/dev/null || true
    install_launcher

    echo
    ok "Done in $(( (SECONDS - start) / 60 )) min. Next steps:"
    cat <<EOF

    qemu-mac new mymac --machine ${MACHINES%% *}     # create a VM
    qemu-mac install mymac ~/Downloads/install.iso   # boot the installer
    qemu-mac run mymac                         # start it afterwards
    qemu-mac help                              # everything else

EOF
    case " $MACHINES " in *" g3 "*)
        echo "    The G3 needs Apple's Beige G3 ROM: qemu-mac new mymac --machine g3 --rom PowerMacG3v3.ROM"
        echo ;;
    esac
}

main "$@"

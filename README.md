# qemu-linux — Power Mac G3, G4 and G5 on Linux

A fork of [cat7/qemu](https://github.com/cat7/qemu) that emulates three PowerPC Macs, made easy to
install and use on Linux. One command builds the emulators, and the `qemu-mac` helper creates and
starts virtual Macs without long QEMU command lines.

| Machine | Firmware | Runs | Branch |
| --- | --- | --- | --- |
| **Beige Power Mac G3** | Apple's Beige G3 ROM (you supply it) | Mac OS 8 – 9.2, Mac OS X 10.0 – 10.2, OS X Server 1.2v3, Linux | `G3-rom` |
| **Power Mac G4** | OpenBIOS (downloaded for you) | Mac OS 9.2, Mac OS X 10.0 – 10.5 | `G4-openbios` |
| **Power Mac G5** | OpenBIOS (downloaded for you) | Mac OS X 10.3.9 – 10.5 | `G5-openbios` |

> [!NOTE]
> This is an experiment and is not meant for upstream QEMU. Mac OS install discs and Apple ROMs
> are **not** included — you need your own.

---

## Contents

- [Install on Linux](#install-on-linux)
- [Quick start](#quick-start)
- [The `qemu-mac` command](#the-qemu-mac-command)
- [VM settings (`vm.conf`)](#vm-settings-vmconf)
- [Updating and uninstalling](#updating-and-uninstalling)
- [Troubleshooting](#troubleshooting)
- [Building by hand](#building-by-hand)
- [macOS and Windows](#macos-and-windows)
- [Machine reference](#machine-reference): [G3](#beige-power-mac-g3-g3-rom) · [G4](#power-mac-g4-g4-openbios) · [G5](#power-mac-g5-g5-openbios)
- [License](#license)

---

## Install on Linux

Paste this into a terminal **as your normal user** (not root — it asks for your password with
`sudo` when it installs packages):

```bash
curl -fsSL https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom/install.sh | bash
```

It asks which machines to build. To choose up front:

```bash
# Just the G4
curl -fsSL https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom/install.sh | bash -s -- --machine g4

# All three
curl -fsSL https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom/install.sh | bash -s -- --machine all
```

Each machine takes about 5–15 minutes to compile, depending on your CPU.

### What the installer does

1. Detects your distribution and installs the build dependencies with its package manager.
2. Downloads the source of each machine you picked (only the latest commit, no history).
3. Compiles it and installs it into `~/.local/share/qemu-linux/<g3|g4|g5>/`.
4. For the G4 and G5, downloads the matching prebuilt `openbios-qemu.elf` firmware.
5. Installs the `qemu-mac` command into `~/.local/bin/`.
6. Deletes the source and build files again (pass `--keep-source` to keep them).

Nothing is installed system-wide apart from the distribution packages from step 1.

### Supported distributions

| Family | Tested on | Also works on |
| --- | --- | --- |
| **Arch Linux** (`pacman`) | Arch Linux | Manjaro, EndeavourOS, CachyOS, Garuda, … |
| **Fedora** (`dnf`) | Fedora 45 | Nobara, Ultramarine, … |
| **Debian** (`apt`) | Debian 13, Ubuntu 24.04 | Linux Mint, Pop!_OS, Zorin, elementary, … |

On other distributions the installer lists what to install by hand; then run it with `--no-deps`.

### Installer options

| Option | Meaning |
| --- | --- |
| `-m, --machine LIST` | `g3`, `g4`, `g5`, `all`, or a list like `g3,g5` |
| `-p, --prefix DIR` | Install somewhere else (default `~/.local/share/qemu-linux`) |
| `-b, --bindir DIR` | Where `qemu-mac` goes (default `~/.local/bin`) |
| `-j, --jobs N` | Parallel compile jobs (default: all CPU cores) |
| `--no-deps` | Skip installing distribution packages |
| `--keep-source` | Keep the source and build trees |
| `-y, --yes` | Never ask anything |
| `--uninstall` / `--purge` | Remove everything (`--purge` also deletes your VMs) |

Prefer to read the script before running it? Clone the repository and run it from there:

```bash
git clone --depth 1 https://github.com/HaraldErik/qemu-linux.git
cd qemu-linux
less install.sh
./install.sh --machine g4
```

> [!TIP]
> If the installer warns that `~/.local/bin` is not in your `PATH`, add
> `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc` (or `~/.zshrc`) and open a new terminal.

---

## Quick start

You need an install CD/DVD image of the Mac OS you want (`.iso`, `.toast`, `.cdr` or an
uncompressed `.dmg`).

### Power Mac G4 — Mac OS 9.2 or Mac OS X 10.0 – 10.5

```bash
qemu-mac new tiger --machine g4                 # 20 GB disk, 1 GB RAM
qemu-mac install tiger ~/Downloads/MacOSX-10.4.iso
```

In the installer, open **Disk Utility** (Mac OS 9: **Drive Setup**), erase the disk, then install
as on a real Mac. When it is done, close the window and start the VM from its disk:

```bash
qemu-mac run tiger
```

### Power Mac G5 — Mac OS X 10.3.9 – 10.5

```bash
qemu-mac new leopard --machine g5               # 40 GB disk, 2 GB RAM, 2 CPUs
qemu-mac install leopard ~/Downloads/MacOSX-10.5.iso
qemu-mac run leopard
```

### Beige Power Mac G3 — Mac OS 8 – 9.2, Mac OS X 10.0 – 10.2

The G3 boots Apple's own ROM. Use the 4 MB version 3 ROM, `PowerMacG3v3.ROM`:

```bash
qemu-mac new classic --machine g3 --rom ~/Downloads/PowerMacG3v3.ROM
qemu-mac install classic ~/Downloads/MacOS9.iso
qemu-mac run classic
```

The G3 ROM ignores QEMU's boot order: a blank disk falls through to the CD, so the install just
works. For Mac OS X or Linux on the G3, set `GOVERNOR=off` with `qemu-mac edit classic`
(see [CPU speed](#running)).

> [!TIP]
> Click inside the window to capture the mouse (or touchpad); press **Ctrl+Alt+G** to release it.
> **Ctrl+Alt+F** toggles full screen. On Mac OS X 10.4 and 10.5 (G4/G5) you can set `TABLET=yes`
> with `qemu-mac edit NAME` so the pointer moves in and out of the window freely. Leave it off for
> Mac OS 9 and Mac OS X 10.0 – 10.3: they have no driver for the USB tablet and the mouse won't move.

---

## The `qemu-mac` command

| Command | What it does |
| --- | --- |
| `qemu-mac new NAME -m g3\|g4\|g5` | Create a VM. Options: `--size 30G`, `--ram 1536`, `--cpus 2`, `--rom FILE` (G3), `--disk FILE` (use an existing image) |
| `qemu-mac install NAME DISC.iso` | Boot from an install disc |
| `qemu-mac run NAME` | Start the VM from its disk |
| `qemu-mac cd NAME DISC.iso` | Start from disk with a CD inserted |
| `qemu-mac list` | List your VMs |
| `qemu-mac edit NAME` | Edit the VM's settings in your `$EDITOR` |
| `qemu-mac show NAME` | Print the full QEMU command line (to copy or tweak) |
| `qemu-mac path NAME` | Print the VM's folder |
| `qemu-mac delete NAME` | Delete a VM and its disk |
| `qemu-mac doctor` | Show which emulators are installed and which audio backends they have |

Anything after `run NAME` goes straight to QEMU, e.g. `qemu-mac run tiger -full-screen`.

Each VM is a folder in `~/.local/share/qemu-linux/vms/NAME/` holding `disk.img`, the PRAM/NVRAM
files, the G3 ROM copy and `vm.conf`. Back it up by copying the folder. Set `QEMU_MAC_VMS` to keep
VMs somewhere else, e.g. `export QEMU_MAC_VMS=/mnt/games/macs`.

---

## VM settings (`vm.conf`)

`qemu-mac edit NAME` opens this file:

```bash
MACHINE=g4
RAM=1024            # MB (G3: at most 1536, G4: at most 2048)
CPUS=1              # G4/G5 only; Mac OS X 10.3 uses at most 2
DISK=disk.img
ROM=                # G3 only
SHARE=""            # host folder shown to the guest as 'Shared'
DISPLAY_UI=gtk      # gtk or sdl
AUDIO=auto          # auto, pipewire, pa, alsa or none
TABLET=no           # yes = mouse follows the host pointer (Mac OS X 10.4+ only)
GOVERNOR=on         # G3 only: on for classic Mac OS, off for Mac OS X / Linux
EXTRA=""            # extra QEMU arguments
```

- **Audio.** `auto` uses PipeWire, or else PulseAudio, whichever is running; with neither the VM is silent. Set `AUDIO=alsa` for a bare ALSA system.
- **Shared folder.** Set `SHARE="/home/you/MacShare"`. The guest needs a driver:
  Mac OS X 10.4/10.5 the [osx9p](https://github.com/cat7/osx9p) kext (the installer puts
  `osx9p-*.iso` next to OpenBIOS in `~/.local/share/qemu-linux/g4/share/qemu-linux/`; attach it with
  `qemu-mac cd NAME …/osx9p-1.1.1.iso`); the G3 needs `virtio-9p.rom` from
  [classicvirtio](https://github.com/cat7/classicvirtio) copied into the VM folder.
- **Graphics cards.** Put the card options in `EXTRA`, for example on the G4:
  `EXTRA="-vga none -device ati-radeon9800,gl=on,romfile=/home/you/roms/radeon9800.rom"`.
  See the machine reference below for every card and its options.
- **More CPUs** (G4/G5): raise `CPUS`. Mac OS X 10.5 deadlocks above about 16.

---

## Updating and uninstalling

Run the install command again — it rebuilds the machines you pick with the latest code. Your VMs
are not touched.

```bash
# Remove the emulators and qemu-mac, keep the VMs
curl -fsSL https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom/install.sh | bash -s -- --uninstall

# Remove everything including VMs
curl -fsSL https://raw.githubusercontent.com/HaraldErik/qemu-linux/G3-rom/install.sh | bash -s -- --uninstall --purge
```

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `qemu-mac: command not found` | `~/.local/bin` is not in `PATH` — see the tip under [Install](#install-on-linux) |
| `ERROR: Dependency "…" not found` while building | Your distribution names a package differently. Install its `-devel`/`-dev` package and rerun with `--no-deps` |
| `python3 venv/ensurepip is missing` | Debian/Ubuntu: `sudo apt install python3-venv` |
| Mouse/touchpad doesn't move | Click in the window first. If it still doesn't move, set `TABLET=no` (`qemu-mac edit NAME`) — Mac OS 9 and Mac OS X 10.0 – 10.3 can't use the USB tablet |
| No sound | `qemu-mac doctor` lists the audio backends; set `AUDIO=pa` or `AUDIO=alsa` in `vm.conf` |
| G4/G5 shows the OpenBIOS prompt instead of booting | The disk has no system yet — use `qemu-mac install NAME DISC.iso` first |
| Classic Mac OS on the G3 quits with "divide by zero" | Keep `GOVERNOR=on` |
| Mac OS 9 on the G3 hangs halfway through the chime | It is reading PRAM written by Mac OS X — give each OS its own VM, or delete `pram.img` and `nvram.img` in the VM folder |
| Wayland: odd mouse or scaling | Try `DISPLAY_UI=sdl`, or start with `GDK_BACKEND=x11 qemu-mac run NAME` |
| `.dmg` won't boot | Compressed DMGs can't be read directly; convert with `dmg2img` |

Still stuck? Run `qemu-mac show NAME`, then run that command in a terminal and look at the error.

---

## Building by hand

If you'd rather not use the script, install the dependencies:

```bash
# Arch
sudo pacman -S --needed base-devel git python ninja pkgconf glib2 pixman libslirp dtc gtk3 sdl2 \
  libepoxy mesa libpulse alsa-lib pipewire zlib zstd bzip2 curl unzip flex bison
# Fedora
sudo dnf install gcc gcc-c++ make git python3 ninja-build pkgconf-pkg-config glib2-devel pixman-devel \
  libslirp-devel libfdt-devel gtk3-devel SDL2-devel libepoxy-devel mesa-libgbm-devel \
  pulseaudio-libs-devel alsa-lib-devel pipewire-devel zlib-devel libzstd-devel bzip2 curl unzip flex bison
# Debian / Ubuntu
sudo apt install build-essential git python3 python3-venv ninja-build pkg-config libglib2.0-dev \
  libpixman-1-dev libslirp-dev libfdt-dev libgtk-3-dev libsdl2-dev libepoxy-dev libgbm-dev \
  libpulse-dev libasound2-dev libpipewire-0.3-dev zlib1g-dev libzstd-dev bzip2 curl unzip flex bison
```

Then build the machine's branch:

```bash
git clone --depth 1 -b G3-rom https://github.com/HaraldErik/qemu-linux.git qemu
cd qemu && mkdir build && cd build
../configure --target-list=ppc-softmmu --enable-slirp --enable-gtk --enable-sdl --disable-docs
make -j"$(nproc)" qemu-system-ppc qemu-img
```

For the G4 use branch `G4-openbios`; for the G5 use `G5-openbios` with
`--target-list=ppc64-softmmu` and `make qemu-system-ppc64`. Those two branches live in
[cat7/qemu](https://github.com/cat7/qemu) (the installer fetches them from there when this fork
doesn't carry them). They need `openbios-qemu.elf`, built from the branch of the same name of
[cat7/openbios](https://github.com/cat7/openbios), or taken from a
[release zip](https://github.com/cat7/qemu/releases).

The binaries are in `build/`. On Linux, use `-audiodev pipewire,id=snd` (or `pa`, `alsa`) where
the examples below say `coreaudio`.

---

## macOS and Windows

Ready-made builds with a GUI for setting up and starting machines, by cat7:

| Machine | Branch | Download |
| --- | --- | --- |
| Beige Power Mac G3 | `G3-rom` | [G3-rom-2026-11-06](https://github.com/cat7/qemu/releases/tag/G3-rom-2026-11-06) |
| Power Mac G4 (OpenBIOS) | `G4-openbios` | [G4-openbios-2026-11-05](https://github.com/cat7/qemu/releases/tag/G4-openbios-2026-11-05) |
| Power Mac G5 (OpenBIOS) | `G5-openbios` | [G5-openbios-2026-11-05](https://github.com/cat7/qemu/releases/tag/G5-openbios-2026-11-05) |

All releases: <https://github.com/cat7/qemu/releases>. To build yourself on macOS use
`--enable-cocoa`; on Windows (MSYS2 UCRT64) use `--enable-sdl --enable-gtk`.

Two more machines have their own repositories:

- The Apple Network Server 700/200 (<https://github.com/cat7/ANS-rom>). It runs AIX 4.1.5 on the
  Network Server ROM 1.1.22, and Mac OS 8.5 on the Network Server ROM 2.0 with an ATI Rage 128 Pro
  card. macOS build with a GUI:
  [ANS-2026-11-07](https://github.com/cat7/ANS-rom/releases/tag/ANS-2026-11-07).
- The 68k Macintosh Quadra (<https://github.com/cat7/m68k-rom>).

---

## Machine reference

The detailed options for each machine. `qemu-mac` sets all of this up for you; this is for
tweaking with `EXTRA=` or running QEMU directly. The examples use Linux audio (`pipewire`); on
macOS use `coreaudio`, on Windows `dsound` plus `-display sdl`.

### Beige Power Mac G3 (`G3-rom`)

The `g3beige` machine of `qemu-system-ppc`, made to run the real Beige G3 ROM. It runs Mac OS 8 to
9.2, Mac OS X 10.0 to 10.2, Mac OS X Server 1.2v3 and Linux.

#### The machine

| | |
| --- | --- |
| Model | Beige Power Mac G3 ("Gossamer") |
| CPU | PowerPC 750 (G3), one CPU |
| Memory | up to 2047 MB (`-m`); the real board takes 768 MB |
| Firmware | Apple's Beige G3 ROM (`-bios`) |
| Host bridge | Grackle |
| I/O controller | Heathrow: ESCC serial ports, Cuda (ADB, clock, PRAM), SWIM3 floppy, AWACS sound, BMAC Ethernet, MESH SCSI, ATA |
| Graphics | ATI Mach64 Rage Pro on board; an ATI Rage 128 Pro can be added as a second card |
| Shared folder | virtio-9p, as a Mac OS volume |

#### What you need

- A Beige G3 ROM image, 4 MB. Use the version 3 ROM (`PowerMacG3v3.ROM`). Not included.
- A Mac OS install CD as an image. Not included.
- An empty disk image: `qemu-img create -f raw macos.img 4G`

#### Running

```bash
qemu-system-ppc \
  -M g3beige -m 512 \
  -bios PowerMacG3v3.ROM \
  -audiodev pipewire,id=snd -global awacs.audiodev=snd \
  -nic user,model=bmac \
  -drive file=macos.img,format=raw,media=disk \
  -cdrom install.iso
```

- **CPU speed.** `-M g3beige,calibration-governor=on|off|mips=N`. The ROM times its CPU-speed
  constants in a 1 ms window; an emulated CPU that runs too fast stores 0 there and Mac OS later
  quits with "divide by zero" errors (the ATAPI CD driver, Open Transport). The governor slows the
  CPU only inside that window. It is on by default (79 MIPS), which classic Mac OS needs; Mac OS X,
  OS X Server and Linux run better with it off (`GOVERNOR=off` in `vm.conf`).
- **Boot device.** The ROM ignores `-boot`. It looks for a blessed System Folder, preferring the
  startup disk saved in PRAM. To boot a CD (or floppy) for sure, attach only that medium and no
  hard disk. With both attached, pick the CD in the Startup Disk control panel and restart; the
  choice is kept across runs.
- **Disks.** `-drive file=...,format=raw,media=disk` is an ATA hard disk; repeat it for a second
  one. `-cdrom` is an ATAPI CD-ROM. SCSI disks and CDs go on the MESH bus:

  ```bash
  -drive file=disk.img,format=raw,if=none,id=shd0 \
  -device scsi-hd,drive=shd0,scsi-id=0
  ```

  The SWIM3 floppy (raw 1440K or 720K images):

  ```bash
  -drive if=none,id=fd,file=floppy.img,format=raw -global swim3.drive=fd
  ```

- **Network.** `-nic user,model=bmac` is the onboard BMAC on slirp NAT: the guest gets 10.0.2.15
  by DHCP, gateway 10.0.2.2. Add `,mac=52:54:00:xx:yy:zz` to fix the MAC address. `-nic none`
  removes the card.
- **ATI FCode ROM.** With a real ATI Mach64 Open Firmware FCode ROM as the card's expansion ROM,
  the ROM's Open Firmware runs it and Apple's ATI display driver binds, which draws faster than the
  generic path: `-global ati-mach64-gt.romfile=ati_fcode.rom`. It is tested with the Mach64 3D Rage
  "GT" FCode ROM (ATI p/n 109-39200-00, FCode 1.53). Not included. With the driver bound, the
  card's DDC reports a "Multiple Scan Display"; set its resolution with
  `-global ati-mach64-gt.xres=1024 -global ati-mach64-gt.yres=768`.
- **Second card.** `-device ati-rage128-pro,addr=0x0e,romfile=rage128pro.rom`.
- **Shared folder** (Mac OS 8.6 and later). The card needs the FCode ROM `virtio-9p.rom`, built
  from [cat7/classicvirtio](https://github.com/cat7/classicvirtio):

  ```bash
  -fsdev local,id=hostshare,path=/path/to/folder,security_model=none,macos_compat=on \
  -device virtio-9p-pci,fsdev=hostshare,mount_tag=Shared,romfile=virtio-9p.rom,addr=0x0d
  ```

- **PRAM and NVRAM.** `pram.img` (Cuda PRAM: startup disk, network settings, time zone) and
  `nvram.img` (Open Firmware NVRAM) are kept in the current directory, created if missing. Delete
  both to zap the PRAM. Give each guest OS its own directory: Mac OS X rewrites the Open Firmware
  settings, and a classic Mac OS boot from the same files then hangs halfway through the startup
  chime. (`qemu-mac` runs each VM in its own folder, so this is handled.)
- **Cursor.** Under classic Mac OS the machine moves the ATI hardware cursor to the host pointer
  itself, because the guest stops doing so during boot. Clicks still go through ADB.

#### Known limits

- One CPU.
- Short system sounds under classic Mac OS can have audible glitches; the Sound Manager's buffer
  is only a few milliseconds deep.
- The Mach64 2D engine has no 1 and 4 bpp modes, polygon or trapezoid fills, or rotating VRAM
  patterns.

### Power Mac G4 (`G4-openbios`)

The `mac99` machine of `qemu-system-ppc`, extended into a New World Power Mac G4 that runs on
OpenBIOS, so no Apple ROM is needed. It runs Mac OS 9.2 and Mac OS X 10.0 to 10.5.

#### The machine

| | |
| --- | --- |
| Model | PowerMac3,1 (PowerMac3,6 with more than 4 CPUs) |
| CPU | PowerPC 7400 (G4); `-smp` up to 32 |
| Memory | up to 2 GB (`-m`) |
| Firmware | OpenBIOS (`openbios-qemu.elf`) |
| Host bridge | UniNorth: PCI, AGP and internal PCI buses |
| I/O controller | KeyLargo: OpenPIC, ESCC serial ports, PMU (or Cuda), two ATA buses, Screamer sound, NVRAM |
| Ethernet | Sun GEM (`sungem`) |
| USB | OHCI; NEC uPD720101 USB 2.0 card (`nec-usb=on`) |
| Graphics | QEMU standard VGA by default; ATI Rage 128 Pro or ATI Radeon 9800 (card ROM needed) |
| Shared folder | virtio-9p, as a Mac OS volume |

#### What you need

- `openbios-qemu.elf` (the installer downloads it).
- A Mac OS 9.2 or Mac OS X 10.0 to 10.5 install CD or DVD as an image (`.iso`, `.toast`, `.cdr`,
  `.dmg`). Not included.
- An empty disk image: `qemu-img create -f raw macosx.img 20G`
- For an ATI card: its Mac ROM image. Not included.

#### Machine options

`-M mac99,option=value,...`

- `via=pmu|pmu-adb|cuda` — the power controller. Use `pmu`: more than one CPU needs a PMU. `pmu`
  gives a USB keyboard and mouse, `pmu-adb` and `cuda` ADB ones.
- `nec-usb=on` — adds the NEC USB 2.0 card (Mac OS X 10.3 and later), for passing host USB devices
  through.
- `decr-cap-ms=N` — fires each CPU's decrementer at least every N ms, so idle CPUs do not sleep
  too long.

#### Installing

The NVRAM is kept only in an attached file. Make it once:

```bash
dd if=/dev/zero of=nvram.img bs=8192 count=1
```

Boot the install CD with `-boot d`:

```bash
qemu-system-ppc \
  -M mac99,via=pmu -m 1024 \
  -bios openbios-qemu.elf \
  -audiodev pipewire,id=snd -global screamer.audiodev=snd \
  -nic user,model=sungem \
  -drive file=macosx.img,format=raw,media=disk \
  -cdrom install.iso \
  -drive if=none,id=nvr,file=nvram.img,format=raw \
  -global macio-nvram.drive=nvr \
  -boot d
```

Erase the disk with Disk Utility (Drive Setup on Mac OS 9) and install as on a real Mac.

#### Running

Leave out `-cdrom` and boot the disk with `-boot c`. Add `-smp 2` or more for more CPUs.

- **Graphics cards.** `-vga none` and one of:
  - `-device ati-rage128-pro,romfile=rage128pro.rom` — for Mac OS 9.
  - `-device ati-radeon9800,gl=off|on|fast,romfile=radeon9800.rom` — Mac OS X 10.3 to 10.5 only,
    with Quartz Extreme and OpenGL. `gl=off` draws in software, `on` through host OpenGL (exact),
    `fast` through host OpenGL (fastest). On macOS, `gl-api=metal` uses Metal instead.
- **Shared folder.**

  ```bash
  -fsdev local,id=hostshare,path=/path/to/folder,security_model=none,macos_compat=on \
  -device virtio-9p-pci,fsdev=hostshare,mount_tag=Shared
  ```

  Mac OS X 10.4 and 10.5 need the [osx9p](https://github.com/cat7/osx9p) kext. Mac OS 8.6 to 9.2
  need the driver that `ndrvloader` (from [cat7/classicvirtio](https://github.com/cat7/classicvirtio))
  loads before the boot:

  ```bash
  -device loader,addr=0x4000000,file=ndrvloader \
  -prom-env 'boot-command=init-program go'
  ```

- **USB tablet.** `-device usb-tablet` makes the mouse follow the host pointer in Mac OS X.

#### Known limits

- At most 2 GB of memory.
- Two of KeyLargo's three ATA buses are modelled.
- The Radeon 9800 runs only on Mac OS X 10.3 to 10.5. Mac OS 9's shared-folder driver does not fit
  in OpenBIOS beside the Radeon 9800's ROM; use the Rage 128 Pro there.
- Mac OS X 10.5 deadlocks above about 16 CPUs.

### Power Mac G5 (`G5-openbios`)

The 64-bit `mac99` machine of `qemu-system-ppc64`, turned into a Power Mac G5 (PowerMac7,3) that
runs on OpenBIOS, so no Apple ROM is needed. It runs Mac OS X 10.3.9 to 10.5.

#### The machine

| | |
| --- | --- |
| Model | PowerMac7,3 |
| CPU | PowerPC 970FX (G5); `-smp` up to 32 |
| Memory | above 2 GB continues at 4 GB, as on the real machine |
| Firmware | OpenBIOS (`openbios-qemu.elf`) |
| Host bridge | U3: AGP bus, HyperTransport, DART (IOMMU), MPIC |
| I/O controller | K2: MPIC, ESCC serial ports, PMU, sound (I2S with a TAS3004 codec), two OHCI USB controllers, NVRAM |
| Storage | K2 ATA-100 (optical drives), K2 SATA ports A and B (hard disks) |
| Ethernet | K2 GMAC (`sungem`) |
| USB 2.0 | NEC uPD720101 card (EHCI) |
| Graphics | QEMU standard VGA by default (1024 x 768); ATI Radeon 9800 or ATI Radeon 7000 in the AGP slot (card ROM needed) |
| Shared folder | virtio-9p, as a Mac OS volume |

#### What you need

- `openbios-qemu.elf` (the installer downloads it).
- A Mac OS X 10.3.9 (G5 build), 10.4 or 10.5 install DVD as an image (`.iso`, `.toast`, `.cdr`,
  `.dmg`). Not included.
- An empty disk image: `qemu-img create -f raw macosx.img 40G`
- For an ATI card: its Mac ROM image. Not included.

#### Machine options

`-M mac99,via=pmu -cpu 970fx`. The keyboard and mouse are USB.

- `decr-cap-ms=N` — fires each CPU's decrementer at least every N ms, so idle CPUs do not sleep
  too long.

The NVRAM (two 8 KB flash banks) is kept in `nvram.img` in the current directory, created if
missing.

#### Installing

Hard disks go on SATA, the DVD on the ATA-100 bus. Boot the DVD with `-boot d`:

```bash
qemu-system-ppc64 \
  -M mac99,via=pmu -cpu 970fx -smp 2 -m 2048 \
  -bios openbios-qemu.elf \
  -audiodev pipewire,id=snd0 -global macio-newworld.audiodev=snd0 \
  -nic user,model=sungem \
  -drive file=macosx.img,format=raw,if=none,id=sata0 \
  -device ide-hd,bus=sata.0,drive=sata0 \
  -cdrom install.iso \
  -boot d
```

Erase the disk with Disk Utility and install as on a real Mac.

#### Running

Leave out `-cdrom` and boot the disk with `-boot c`.

- **Graphics cards.** `-vga none` and one of:
  - `-device ati-radeon9800,bus=pci.0,addr=0x10,gl=off|on|fast,romfile=radeon9800.rom` — Quartz
    Extreme and OpenGL. `gl=off` draws in software, `on` through host OpenGL (exact), `fast`
    through host OpenGL (fastest).
  - `-device ati-vga,model=rv100,bus=pci.0,addr=0x10,agp=on,romfile=radeon7000.rom` — the Radeon
    7000.
- **Shared folder.** The card goes in a PCI-X slot:

  ```bash
  -fsdev local,id=hostshare,path=/path/to/folder,security_model=none,macos_compat=on \
  -device virtio-9p-pci,bus=pcix1,addr=0x2,fsdev=hostshare,mount_tag=Shared
  ```

  Mac OS X needs the [osx9p](https://github.com/cat7/osx9p) kext.
- **USB tablet.** `-device usb-tablet` makes the mouse follow the host pointer.

#### Known limits

- Mac OS X 10.3 uses at most 2 CPUs.
- Mac OS X 10.5 deadlocks above about 16 CPUs.

---

## License

QEMU as a whole is released under the GNU General Public License, version 2. For full licensing
details, consult the [LICENSE](LICENSE) file. The Power Mac machines are by
[cat7](https://github.com/cat7/qemu); this fork adds the Linux installer and `qemu-mac`.

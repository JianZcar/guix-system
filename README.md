# Zena Guix

Not a flavor. Not a distribution. A set of system dotfiles that boots straight
into a complete, coherent desktop.

Zena Guix is my daily-driver Guix configuration. It wires MangoWM, Noctalia, a
CachyOS kernel, NVIDIA, and the supporting services into one declarative system
that builds with `guix system` — no post-install checklist, no "now go
configure the rest yourself" step.

It was written for me first. But if you are new to Guix and want a real example
to learn from, or if you like the comfort of letting someone else make the
opinionated choices, this is a good place to start.

## What you get

- **Desktop:** MangoWM with a Noctalia shell and greeter, tied together with
  patched `xdg-desktop-portal-wlr`, a greetd session, and a per-user desktop
  shepherd that starts PipeWire, WirePlumber, foot server, ssh-agent, Kanshi,
  and Noctalia.
- **Kernel:** CachyOS built by Guix from source, with the BORE scheduler,
  Clang/LLVM ThinLTO, and native x86-64 tuning. Series and release are
  parameters, so updating the kernel is a one-line change.
- **NVIDIA:** Version-selectable nonguix driver and kernel module. The module is
  built against the exact CachyOS kernel you configure, so the two cannot
  drift apart. Flip `enable-nvidia?` to get plain Steam and Heroic instead.
- **Storage:** Btrfs root with `compress=zstd:3`, `space_cache=v2`, and
  `no-atime`, EFI boot, and a LUKS toggle with self-describing UUID variables.
- **Services:** Thermal management, zram, earlyoom, fstrim, polkit, elogind,
  upower, power-profiles-daemon, udisks, Bluetooth named after the host,
  NetworkManager, wpa-supplicant, Tailscale, nftables, NTP, rtkit, rootless
  Podman, libvirt, virtlog, and ddcutil udev rules.
- **Configuration out of the box:** Mango, Noctalia, foot, dconf, Thunar,
  ALSA/PipeWire, and firewall rules are installed via `etc-service`, plus
  helpers like `nv` and `run-game`.

## The knobs

Everything machine-specific sits at the top of `configuration.scm`:

- `host-name` and `users`
- `enable-luks?`, `luks-partition-uuid`, `root-partition-uuid`,
  `efi-partition-uuid`
- `kernel-arguments` (the v4l2 loopback arguments are appended automatically)
- `kernel-cachyos #:series` / `#:release`, `enable-nvidia?`, and
  `nvidia-version`

Derived values such as podman subuid ranges and noctalia passwordless sync users
are computed from `users` inside `modules/services.scm`, so there is only one 
place to edit your accounts.

## Layout

- `configuration.scm` — the operating system definition and your machine values
- `channels.scm` — guix, nonguix, rosenthal, mangowm, noctalia, midnight
- `modules/kernel.scm` — CachyOS kernel and its matching NVIDIA module
- `modules/nvidia.scm` — versioned driver lookup and the NVIDIA transformation
- `modules/services.scm` — the service stack and session configuration
- `modules/packages.scm` — package list and patched packages
- `modules/desktop.scm` — MangoWM session, portal patches, desktop shepherd
- `modules/files.scm` — config files installed into `/etc`
- `modules/signing-keys.scm` — nonguix substitute signing key
- `scripts/` — shell helpers referenced by the generated programs

## Getting started

Pull the channels listed in `channels.scm`, then build the system:

```sh
guix pull -C channels.scm
guix system build configuration.scm
```

The first build and installation can take a long time: the CachyOS kernel and
its NVIDIA module are compiled from source, so a cold cache means a lot of work.
Be patient. Later builds reuse those results and are much faster.

Review the machine-specific values at the top of `configuration.scm` before
deploying. Replace `root-partition-uuid` if you turn LUKS off.

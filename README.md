# iQOO 13 Root Research

This repository contains the source tree copied from the IonStack exploit
project and arranged at the repository root for the iQOO 13 research target.

The wallpaper payload and its framework-restart path were removed from this
copy. The remaining code retains the exploit, kernel read/write research,
root handoff, and embedded KernelSU daemon paths from the source project.

## Build

The default Make target is `iQOO-13`:

```sh
make
```

The build requires an Android NDK toolchain for AArch64. This repository is a
research artifact; the target header must be independently checked against the
exact device kernel before any build or device testing.

## Layout

- `preload.c` — preload entry point
- `root.c` — root handoff and result reporting
- `targets/iQOO-13/target.h` — target-specific configuration
- `su_daemon.c` and `su_blob.S` — embedded daemon payload
- `release/preload.so` — supplied prebuilt preload artifact

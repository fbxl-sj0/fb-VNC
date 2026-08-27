# Building and portability

## Requirements

The supported toolchain is FreeBASIC 1.20.3 with the new gfxlib selected by `-gfx3`. A POSIX-compatible `make` is convenient but not required. omaGUI is already present under `src/omaGUI-main`; it does not need to be installed separately.

No operating-system SDK, native socket library, compression library, or image codec is required.

## Standard build

From the `FB-VNC` project directory:

```text
make
```

This produces `fbvnc`. The complete compiler command is represented by the variables in the top-level `Makefile`:

```text
fbc -gfx3 -O 2 -exx -w all -mt \
    -i src -i src/omaGUI-main \
    src/main.bas src/network.bas src/des.bas src/threads.bas \
    src/rfb.bas src/scaler.bas src/ui.bas -x fbvnc
```

The important flags are:

| Flag | Reason |
| --- | --- |
| `-gfx3` | Selects the resizable gfxlib implementation used by the UI backend. |
| `-O 2` | Enables the optimizations required for practical scaling and decoding performance. |
| `-exx` | Keeps FreeBASIC runtime checking enabled. |
| `-w all` | Enables compiler diagnostics. |
| `-mt` | Selects the thread-safe runtime and enables the threaded session pipeline where supported. |
| `-i` paths | Finds project headers and the vendored omaGUI headers. |

Use a different compiler executable without editing the Makefile:

```text
make FBC=/opt/freebasic/bin/fbc
```

If `FBCFLAGS` is overridden, retain both include paths and `-gfx3` unless the replacement build deliberately provides equivalents.

## Serial fallback build

```text
make serial
```

This produces `fbvnc-serial` without `-mt`. It is useful for validating the single-thread event loop and for targets whose runtime has no threading support.

The regular source also contains a compile-time fallback. `threads.bi` enables workers only when `__FB_MT__` is defined and the target is not DOS or JavaScript. If worker resources or either worker thread cannot be created at run time, the session continues serially and the reason appears in the connection information panel.

A compiler that does not accept `-mt` can build the normal target with:

```text
make THREADFLAGS=
```

## gfxlib2 comparison build

```text
make gfx2
```

This produces `fbvnc-gfx2` without changing the supported `fbvnc` binary. The target exists for ports where gfxlib3 is unavailable and for repeatable backend comparisons. It uses the same RFB, threading, omaGUI, and clipboard sources, with the CPU scaler selected instead of the gfxlib3 opaque-surface extension.

The 2026-08-27 paired profile recorded 510 gfxlib2 flips and 844 gfxlib3 flips during equal scheduled localhost runs. Profiling perturbs both programs, so those counts are diagnostic rather than a refresh-rate guarantee, but they confirm that gfxlib2 is not the faster viewer backend on the development system. See [Performance findings](performance-findings-2026-08-27.md).

## Haiku preparation

The planned Haiku port starts with the gfxlib2 target. On a native Haiku
FreeBASIC installation, use:

```text
make gfx2
```

Keep `THREADFLAGS=-mt` when the installed runtime supports FreeBASIC threads.
If that toolchain does not provide the thread-safe runtime, use
`make gfx2 THREADFLAGS=`; the same sources then select the serial pipeline.

The Linux development toolchain was also asked to compile every viewer module
through FreeBASIC's `haiku-x86_64` target front end, once with `-mt` and once
without it. Both passes generated all seven modules and excluded every
gfxlib3-only surface and text command. This catches FreeBASIC declarations,
target conditionals, and type errors, but it is not a substitute for the first
native Haiku link and window-system run because the Linux machine has no Haiku
sysroot or linker installed.

The live gfxlib2 test covered resizable DesktopSize changes, Fit, clipped 1:1
rendering and both scrollbars, full-screen screen recreation, the
Ctrl-Alt-Shift-F shortcut, omaGUI overlays, double-buffered presentation, and
the threaded RFB pipeline. Clipboard code is shared by both viewer backends
and remains independent of the host clipboard API.

## Other build targets

| Target | Result |
| --- | --- |
| `make gfx2` | Builds the optional `fbvnc-gfx2` compatibility executable. |
| `make test` | Builds and runs DES, scaler, and server-address parser tests. |
| `make perf` | Runs the 4K-to-720p scaler benchmark. |
| `make perf-rfb-server` | Builds and starts a localhost Raw RFB benchmark server. |
| `make clean` | Removes generated viewer and test binaries. |

The transport benchmark waits for a viewer. Run it in one terminal and connect `fbvnc` to `127.0.0.1::5999` from another.

## Portability model

The project uses the same FreeBASIC interfaces on every target:

- networking through `OPEN TCP`, `GET`, `PUT`, `EOF`, and `EOC`;
- display and input through gfxlib events, with the opt-in `fbgfx3.bi` surface API in the default build;
- optional synchronization through FreeBASIC threads, mutexes, and conditions;
- bulk copies through `__builtin_memcpy`, which is a compiler intrinsic rather than an operating-system API.

The supported graphical build uses gfxlib3. The resize, full-screen transition, and omaGUI double-buffer path are tested against that backend. The maintained gfxlib2 target provides a portable fallback, but its older synchronization and presentation path is slower in the recorded viewer workload.

Endianness-sensitive RFB operations are written explicitly. The fastest Raw copy path is used only on compatible little-endian machines; other targets retain the byte-assembly path.

## Memory expectations

The viewer keeps a 32-bit internal framebuffer. Its CPU allocation is therefore approximately `width * height * 4` bytes. The default build also keeps one remote-sized opaque gfxlib3 surface. The gfxlib2 or allocation-failure path creates a reusable 32-bit presentation image sized to the currently visible remote rectangle. The threaded build allocates an 8 MiB incoming pipe and a 1 MiB outgoing pipe. gfxlib and omaGUI maintain two display pages for flicker-free presentation.

The protocol limit for a single framebuffer allocation is 512 MiB. A platform can fail an otherwise valid allocation earlier because of its address space or available memory. On memory-constrained systems, prefer smaller remote desktops and the serial build.

<!-- end of building-and-portability.md -->

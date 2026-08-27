# Portable FreeBASIC VNC Viewer

This project is a VNC viewer written entirely in standard FreeBASIC 1.20.3. It uses `OPEN TCP` for the wire, gfxlib3 for the resizable window, and no platform APIs or separately linked third-party libraries. The source distribution vendors omaGUI for its desktop controls.

The interface follows the TightVNC viewer workflow: an omaGUI connection dialog, shared/view-only options, a session toolbar, full-screen mode, scale-to-fit and one-to-one modes, refresh, Ctrl-Esc, Ctrl-Alt-Del, connection information, and manual portable clipboard exchange. omaGUI creates two gfxlib pages; the viewer renders a complete hidden frame and flips it into view only when something changes. In the default build, decoded dirty rows are uploaded to an opaque gfxlib3 surface and `Gfx3SurfaceBlitScaled` performs nearest-neighbour scaling on the GPU. The gfxlib2 build and gfxlib3 allocation-failure path retain the reusable CPU image scaler.

## Documentation

The [complete documentation set](doc/README.md) includes the user guide, command-line reference, build and portability notes, protocol and security coverage, architecture, performance testing, troubleshooting, and developer guidance.

The receive path batches available `OPEN TCP` data into a 64 KiB client buffer. Raw framebuffer data is decoded directly into the framebuffer, including a native 32-bit copy path on compatible little-endian machines. Localhost connections prefer Raw automatically because it is much less expensive for high-motion video. Remote connections retain Hextile by default to conserve bandwidth; `--raw` or the connection-dialog checkbox selects Raw on a fast LAN.

On targets with FreeBASIC threading, three execution lanes run concurrently:

- the main thread owns gfxlib3 rendering, window events, and complete-page presentation
- the decoder thread owns RFB parsing and framebuffer updates
- the communications thread becomes the sole owner of `OPEN TCP` reads and writes after negotiation

Communications and decoding exchange bytes through bounded queues. The receive side uses an 8 MiB ring and reads up to 1 MiB per `OPEN TCP` operation, which is large enough to hold a complete 1080p 32-bit frame without wrapping. A framebuffer mutex prevents the decoder from changing or reallocating pixels while gfxlib3 builds its hidden page. The mutex covers pixel access and a small metadata snapshot, not toolbar or overlay drawing. Completed decoder updates are coalesced to a maximum of 60 presentations per second so excess updates replace an unshown frame instead of competing with the decoder. Keeping graphics presentation on the main thread follows the window-system constraint shared by the supported gfxlib3 backends.

The source checks `__FB_MT__` and excludes targets with deliberate no-thread runtimes. It also checks every synchronization allocation and both `ThreadCreate` results. When threads are unavailable, the viewer continues with the original serial event-loop pipeline.

gfxlib3 queues a presentation when `ScreenSet` changes the visible page. The omaGUI portability backend therefore does not precede that operation with `ScreenSync` in a gfxlib3 build. Doing both created two presentation boundaries and reduced the measured page rate to about half the refresh rate. The gfxlib2 compatibility build retains its required `ScreenSync` behavior.

omaGUI's gfxlib3 text path submits antialiased pixels as one alpha-point packet per string. This avoids the `Point` reads used by its portable gfxlib2 blend fallback. Keeping the scaled remote surface and the UI on queued GPU operations eliminated steady work-page downloads in the recorded localhost profile. This gate changes no clipboard code or host-clipboard policy.

## Build

```text
make
```

The build command is equivalent to:

```text
fbc -gfx3 -O 2 -exx -w all -mt -i src -i src/omaGUI-main \
    src/main.bas src/network.bas src/des.bas src/threads.bas src/rfb.bas \
    src/scaler.bas src/ui.bas -x fbvnc
```

Only FreeBASIC's runtime and gfxlib3 are linked. The `-gfx3` switch selects the new gfxlib required for `GFX_RESIZABLE` and `EVENT_WINDOW_RESIZE`.

To build the compile-time serial fallback explicitly:

```text
make serial
```

This produces `fbvnc-serial` without `-mt`. A target whose compiler does not accept `-mt` can also build the normal executable with `make THREADFLAGS=`.

A maintained gfxlib2 compatibility build is also available:

```text
make gfx2
```

This produces `fbvnc-gfx2`. It is the intended starting point for the Haiku
port and for other targets where gfxlib3 is unavailable. gfxlib3 remains the
Linux default because the paired profiling run recorded in [Performance
findings](doc/performance-findings-2026-08-27.md) presented substantially more
frames in the same interval.

## Run

Start the connection dialog:

```text
./fbvnc
```

Connect to VNC display 1 or a literal port:

```text
./fbvnc server.example:1
./fbvnc server.example::5901
```

Run `./fbvnc --help` for all startup options. Supplying `--password` exposes the password to process-list tools, so the graphical password field is preferable.

Inside a session, F8 hides or restores the toolbar. Ctrl-Alt-Shift-F enters or leaves full screen. Full-screen mode removes both the viewer toolbar and status bar, giving the remote desktop the complete display while preserving the saved toolbar preference for windowed mode. In one-to-one mode, click the horizontal or vertical scrollbar tracks to move around a desktop larger than the window.

## Supported RFB features

- RFB 3.3, 3.7, and 3.8 negotiation
- No authentication and classic VNC authentication
- Built-in DES implementation for VNC challenge-response
- 32-bit true-colour framebuffer negotiation
- Raw, CopyRect, RRE, CoRRE, and Hextile encodings
- LastRect, DesktopSize, XCursor, RichCursor, and PointerPos pseudo-encodings
- Keyboard, pointer, mouse wheel, bell indication, and clipboard messages
- Shared and exclusive session requests
- View-only operation

The cursor-shape payloads are consumed but gfxlib's local pointer is used. This avoids platform cursor APIs while preserving correct stream synchronization.

## Deliberate portability limits

Tight, Zlib, ZRLE, and JPEG encodings are not negotiated. Those formats require DEFLATE or JPEG codecs, which standard FreeBASIC does not provide. Hextile is the best encoding shared with TightVNC that stays inside the no-external-library requirement.

Classic VNC authentication is not secure encryption. It limits passwords to eight effective bytes and does not encrypt the session. Use the viewer on a trusted network or through a separately established secure tunnel.

The manual clipboard panel is intentional. It receives RFB `ServerCutText` data and sends RFB `ClientCutText` data without depending on a host operating system clipboard. The viewer defines omaGUI's `OMAGUI_PORTABLE_ONLY` gate, which selects omaGUI's bounded process-local clipboard fallback. Normal omaGUI builds do not define that gate, so their existing host clipboard support remains available.

## Tests

```text
make test
```

The test suite verifies the VNC DES response against a known vector, the CPU fallback scaler's fit and clipping rules, and TightVNC-style IPv4, host-name, and IPv6 address parsing. Runtime integration can be tested against TightVNC with a temporary server, for example display `:9` on TCP port 5909.

Run the repeatable 3840 by 2160 to 1280 by 720 nearest-neighbour scaling benchmark with:

```text
make perf
```

The benchmark reports elapsed time, milliseconds per frame, megapixels per second, and a framebuffer checksum. The checksum prevents an optimizing compiler from treating the render as unused work.

The dated [performance findings](doc/performance-findings-2026-08-27.md) record the localhost viewer/server test conditions, raw measurements, rejected hypotheses, and the changes retained from profiling.

For an end-to-end localhost Raw transport benchmark, run `make perf-rfb-server` in one terminal and connect the viewer to `127.0.0.1::5999`. The server sends 120 complete 1920 by 1080 frames and reports frames per second and payload MiB per second. It uses the same standard FreeBASIC `OPEN TCP` implementation as the viewer.

<!-- end of README.md -->

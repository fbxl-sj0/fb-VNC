# Troubleshooting

## The viewer does not connect

Check the server form first. `host:1` means port 5901, while `host::5901` means literal port 5901. Bracket an IPv6 address before adding a suffix, for example `[::1]::5901`.

`OPEN TCP` reserves commas and equals signs, so the parser rejects hosts containing either character. The port must be from 1 through 65535, and a display number must be from 0 through 59635.

If the message reports `OPEN TCP` failure, confirm that the server is listening on the selected address and that the target's FreeBASIC runtime has TCP support.

## Authentication fails

The viewer supports only None and classic VNC authentication. It does not support VeNCrypt, TLS, SASL, Unix login, or vendor-specific security types.

Classic VNC passwords have eight effective bytes. Confirm that the server is configured for type 2 VNC authentication and that the first eight bytes match. An RFB 3.8 server may return a more specific rejection reason, which the viewer includes in its error text.

## The session connects but no desktop appears

The server must send one of Raw, CopyRect, RRE, CoRRE, or Hextile. A server configured to require Tight, ZRLE, Zlib, or JPEG without Raw fallback is incompatible with this portable build.

Use Refresh to request a non-incremental update. If the remote size changed, the server must use the DesktopSize pseudo-encoding before sending rectangles in the new coordinate space.

## Video is slow on a local connection

Confirm in Info that the encoding preference starts with Raw and execution is threaded. Loopback normally selects Raw automatically. For an address that is locally routed but not recognized as loopback, reconnect with `--raw` or the dialog checkbox.

Try 1:1 mode to separate decoder throughput from scaling cost. In the default build, compare gfxlib3 `transform` and execution counts; in `fbvnc-gfx2`, a much larger remote desktop fitted into a small window requires a CPU destination-pixel pass for every presentation.

Use the benchmarks in [Performance and testing](performance-and-testing.md) before changing buffer sizes or locks.

The supported viewer backend is gfxlib3. `fbvnc-gfx2` is a compatibility and comparison build; it presented fewer frames in the recorded localhost workload. Do not switch the viewer to gfxlib2 merely because the matching server captures faster with that backend. Capture and presentation exercise different gfxlib paths.

## The session says SERIAL

The compiler may have omitted `-mt`, the target may deliberately disable worker support, or worker resources could not be allocated. Open Info to see the runtime fallback reason.

Rebuild with the standard `make` target and confirm that `THREADFLAGS` contains `-mt`. DOS and JavaScript intentionally use the serial path.

## A desktop larger than the window looks clipped

In Fit mode, the entire desktop should be visible with aspect-preserving borders. In 1:1 mode, scrollbars appear when needed. Click their tracks to change `scrollX` or `scrollY`.

If the local window is extremely small, enlarge it so the viewport remains usable around the toolbar, status bar, and scrollbars.

## Input does not reach the server

Check whether the toolbar says View and whether the status bar contains `VIEW ONLY`. Toggle it back to Control if remote input is intended.

Only keys with printable byte values or a defined X11 keysym mapping are sent. The mapping includes navigation keys, modifiers, Insert/Delete, F1 through F12, and common control keys. Platform-specific multimedia keys are not translated.

If focus changes while a modifier is held, the viewer sends releases for Shift, Ctrl, Alt, and AltGr to avoid a stuck remote modifier.

## Clipboard does not affect the host clipboard

That is intentional. Open Clipboard, edit the process-local text field, and select Send. Incoming `ServerCutText` becomes the next clipboard draft. View-only mode suppresses outgoing text.

## Full screen has no toolbar or status bar

That is the intended remote-computer presentation. Use Ctrl-Alt-Shift-F to return to the saved resizable window. F8 controls the toolbar preference used in windowed mode.

## The window flickers or tears

The viewer is designed to compose a complete hidden gfxlib page before every flip. Confirm that the build uses the vendored omaGUI implementation and `-gfx3`. Direct modifications that draw to the visible page or call gfxlib from a worker thread bypass this guarantee.

If a gfxlib3 profile reports two `present` operations for every `page` operation, check that `backend_Flip` has not regained a `ScreenSync` call in the gfxlib3 branch. If upload bytes track the complete local window, check for new direct writes through the page's `ScreenPtr`; remote pixels should normally pass through the opaque surface. If steady download bytes are nonzero, look for `Point`, `Get`, or CPU alpha blending after `Gfx3SurfaceBlitScaled`. omaGUI text should use its gfxlib3 alpha-point packet path.

<!-- end of troubleshooting.md -->

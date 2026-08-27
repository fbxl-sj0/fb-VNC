# Architecture

## Module map

| Module | Owns |
| --- | --- |
| `main.bas` | Defaults, command-line parsing, program exit status. |
| `ui.bas` | gfxlib window, omaGUI controls, page flips, layout, input translation. |
| `rfb.bas` | Handshake, security, message parsing, decoding, outgoing RFB messages. |
| `network.bas` | Standard FreeBASIC `OPEN TCP` operations and byte order. |
| `threads.bas` | Optional workers, byte pipes, conditions, and framebuffer synchronization. |
| `scaler.bas` | Clipped 32-bit nearest-neighbour fallback presentation. |
| `des.bas` | Classic VNC challenge-response operation. |
| `common.bi` | Shared options, client state, limits, and ownership fields. |

omaGUI is included once from `ui.bas` with `OMAGUI_IMPLEMENTATION`. `OMAGUI_PORTABLE_ONLY` selects its bounded process-local clipboard gate for this application.

## Connection lifecycle

```text
command line or dialog
        |
        v
parse host and port
        |
        v
OPEN TCP and negotiate RFB/security
        |
        v
allocate framebuffer and send client preferences
        |
        +----------------------------+
        |                            |
        v                            v
start worker pipeline          use serial fallback
        |                            |
        +-------------+--------------+
                      v
             render and handle input
                      |
                      v
             stop workers, close TCP,
             free framebuffer
```

Negotiation is serial even in a threaded build. This keeps protocol startup simple and ensures any bytes read beyond the handshake can be moved into the incoming pipe before workers are released.

## Threaded session

On supported `-mt` builds, the active session has three execution lanes:

| Lane | Exclusive responsibilities |
| --- | --- |
| Main | gfxlib events, omaGUI, surface upload/scaling, hidden-page composition, and page flips. |
| Communications | All `OPEN TCP` reads and writes after negotiation. |
| Decoder | RFB message framing, rectangle decoding, update requests, clipboard state, and framebuffer mutation. |

The communications worker writes incoming bytes to an 8 MiB ring and drains outgoing messages from a 1 MiB ring. It reads at most 1 MiB per network operation and writes at most 64 KiB per operation. The decoder consumes incoming bytes and blocks on a condition when the pipe is empty.

An outgoing-writer mutex keeps each logical RFB message contiguous. This matters for messages such as `ClientCutText`, where another producer must not insert an update request between the header and text.

## Framebuffer synchronization

The decoder holds the framebuffer mutex while processing one complete `FramebufferUpdate`. This covers rectangle writes and any framebuffer reallocation caused by DesktopSize.

The main thread holds the same mutex while it:

1. calculates the current remote layout;
2. uploads complete affected row spans to the gfxlib3 surface, or uses the reusable CPU image fallback;
3. snapshots connection metadata needed by the toolbar and status bar.

`Gfx3SurfaceUpload` copies its input into the renderer command before returning, so releasing the mutex after the upload cannot expose a partially changed command payload. The main thread then draws omaGUI chrome and performs the clipped surface transform without holding the framebuffer mutex. This keeps toolbar work out of the pixel critical section and allows decoding of the next update to begin sooner.

No thread other than the communications worker touches the TCP handle once workers are released. No worker calls gfxlib.

## Serial session

Targets without worker support keep all work on the gfxlib owner thread. Each event-loop pass processes at most eight available server messages before returning to window events. This bound prevents a busy server from making the local window unresponsive.

The RFB, scaler, and UI paths are otherwise the same as the threaded build. The Info panel and status bar report `SERIAL`.

## Rendering and double buffering

omaGUI creates two gfxlib pages. The viewer renders a complete frame into the hidden page and calls `backend_Flip` only when the framebuffer, window, option state, or overlay needs presentation. Partial remote updates never become partially visible.

On gfxlib3, `ScreenSet` both exchanges the work and visible page and queues presentation. Calling `ScreenSync` immediately before it created a second presentation boundary, so the gfxlib3 path uses `ScreenSet` alone. The optional gfxlib2 build retains `ScreenSync` before page selection because that backend uses the older presentation model.

Writing remote pixels directly through the hidden page's `ScreenPtr` forced gfxlib3 to treat the complete page as externally mutable. The default path now keeps a remote-sized opaque surface, uploads only dirty row spans, and calls `Gfx3SurfaceBlitScaled` with nearest-neighbour filtering. The active gfxlib `View Screen` clips the transform to the viewport so a one-to-one desktop cannot overwrite its scrollbars.

omaGUI submits gfxlib3 antialiased text through `Gfx3DrawPoints`. The alpha blend therefore stays on the GPU even when an overlay is drawn after the remote transform. gfxlib2 retains omaGUI's `Point` plus `PSet` software blend. If the opaque surface API or allocation fails, the viewer scales into one cached 32-bit image and uses `Put ... PSet`; if that image also fails, it retains the checked direct-page fallback rather than dropping the frame.

Threaded decoder generations are coalesced to a maximum of 60 presentations per second. A newer completed framebuffer replaces an older frame that has not yet been shown. Window events and local UI actions still trigger immediate redraws.

## Scaling

Fit calculations use integer cross-products to preserve aspect ratio without floating-point boundary errors. The result is shared by the gfxlib3 transform and CPU fallback so pointer mapping and borders do not depend on the selected backend.

The default gfxlib3 build gives the complete source and destination rectangles to `Gfx3SurfaceBlitScaled`. One-to-one scrolling uses the same transform with an active viewport clip. The CPU fallback copies each visible one-to-one row with `__builtin_memcpy`; scaled fallback rendering builds one horizontal source-coordinate map per presentation and reuses it for every destination row.

The remote framebuffer and gfxlib3 surface remain allocated at their full dimensions regardless of the local viewport. A desktop larger than the window is therefore scaled or scrolled, never truncated. The CPU fallback staging image covers only the clipped viewport, so it does not process pixels hidden beyond the current scroll position.

## Failure and shutdown

Worker creation is all-or-fallback: every allocation, mutex, condition, and both threads must succeed before the session becomes threaded. Partial startup is stopped, joined, and freed before serial work continues.

A worker failure records one shared error, requests both workers to stop, and wakes all condition waiters. The main thread observes the failure, joins workers, disconnects, and returns to the connection dialog. Normal application shutdown follows the same join-before-free rule.

<!-- end of architecture.md -->

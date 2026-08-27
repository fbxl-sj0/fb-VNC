# Developer guide

## Source boundaries

Keep changes within the module that owns the behavior:

| Change | Primary module |
| --- | --- |
| Command-line option or default | `main.bas`, `common.bi` |
| Address parsing or graphical control | `ui.bas` |
| RFB message or encoding | `rfb.bas` |
| TCP readiness or exact I/O | `network.bas` |
| Worker, queue, or framebuffer synchronization | `threads.bas` |
| Fit geometry or CPU fallback scaling | `scaler.bas` |
| Classic VNC DES | `des.bas` |

Do not move gfxlib calls into a worker. Do not let the RFB decoder draw controls. Do not make network helpers choose protocol behavior.

## Adding an RFB encoding

1. Define the signed 32-bit wire value in `rfb.bas`.
2. Add it to `RfbSendEncodings` only after a complete decoder exists.
3. Validate rectangle bounds before reading the payload.
4. Validate every server-controlled count before multiplication or allocation.
5. Decode under the existing framebuffer update lock.
6. Preserve stream alignment on every successful path.
7. Reject malformed payloads through `RfbFail` with a stable application-facing message.
8. Add deterministic tests for minimum, boundary, malformed, and representative payloads.

An unknown encoding cannot be skipped generically because most encoding payloads have no outer byte length. Failing the session is safer than guessing.

## Adding a server message

Add the type to the `RfbProcessOneMessage` dispatch only when its exact length and validation rules are known. Store UI-visible state under the framebuffer mutex or add a dedicated synchronization rule and document it.

## Adding a toolbar action

Toolbar drawing, labels, hit testing, and action dispatch must remain in the same order. Update:

1. `DrawToolbar`;
2. the label array in `ToolbarActionAt`;
3. `HandleToolbarAction`;
4. the user-guide toolbar table;
5. tests when the action changes protocol state.

Controls are rendered with omaGUI widgets, while event routing remains explicit in `ui.bas`. This separation keeps omaGUI portable and avoids hidden control callbacks.

## Threading rules

- The communications worker is the sole TCP-handle owner after startup.
- The decoder is the sole incoming-pipe consumer and framebuffer writer.
- The main thread is the sole gfxlib and omaGUI owner.
- Acquire the framebuffer mutex before reading or changing framebuffer pointers, dimensions, or shared clipboard and bell state.
- Keep UI rendering outside the framebuffer critical section.
- Serialize complete outgoing RFB messages with `outgoingWriterMutex`.
- Never free a pipe, mutex, condition, or framebuffer until its worker has been asked to stop and joined.
- Wake every condition that could contain a waiter during shutdown or failure.

When adding synchronization, document its owner and lock scope beside the state definition and operation. Avoid acquiring multiple pipe mutexes at once.

## Serial compatibility

Every feature must continue to work when `VNC_THREAD_SUPPORT` is zero. The RFB layer chooses threaded transport only through its existing hooks; it must retain the `network.bas` path. The UI must not assume that decoder generations exist.

Build and run all three configurations:

```text
make
make serial
make gfx2
```

## Presentation ownership

`UiState.frameSurface` belongs exclusively to the main gfx thread and to the current gfxlib3 screen mode. Create or replace it only through `EnsureFrameSurface`. Release it before `backend_SetWindowMode`, on disconnect, and before shutting down gfxlib because `ScreenRes` destroys mode-owned opaque surfaces.

The decoder unions every completed framebuffer rectangle into dirty bounds under the framebuffer mutex. The renderer clears `framebufferDirtyValid` only after `Gfx3SurfaceUpload` succeeds. It currently uploads complete dirty row spans from x zero because the public upload command copies `pitch * height` bytes; passing an interior x pointer with a full framebuffer pitch could read beyond the source allocation on the final row.

`UiState.frameImage` and its pixel pointer are the gfxlib2 and allocation-failure fallback. They also belong exclusively to the main gfx thread. `ImageInfo` exposes writable image memory, so no worker may cache, replace, or write that pointer. Reallocate the image only through `EnsureFrameImage`, and release it before shutting down gfxlib.

Keep the image sized to the clipped visible remote rectangle. A full remote-sized image would waste allocation, scaling, and upload work when a one-to-one desktop is larger than the viewport. Preserve `RenderFramebufferDirect` as the allocation-failure fallback for targets that cannot provide the requested 32-bit image.

In a gfxlib3 build, omaGUI batches every antialiased text string through `Gfx3DrawPoints`. Do not restore destination `Point` reads in this path: a read after the remote transform can download the complete work page once per frame. The gfxlib2 branch deliberately retains the software blend.

`backend_Flip` deliberately differs by backend. gfxlib3 queues presentation as part of `ScreenSet`, while gfxlib2 retains `ScreenSync` before exchanging pages. Do not make those paths identical without profiling `present` and `page` counts on both backends.

## Portability rules

- Use standard FreeBASIC and gfxlib operations.
- Do not include platform socket, window, cursor, or clipboard headers.
- Keep integer byte-order conversion explicit.
- Treat alignment and host endianness as runtime constraints on fast paths.
- Use checked `ULongInt` arithmetic before converting lengths to `Integer`.
- Preserve the distinction that `EOF` means no byte is waiting and `EOC` means the TCP connection ended.
- Keep `OMAGUI_PORTABLE_ONLY` scoped to this application.

## Documentation and source style

Every source file begins with its project, purpose, responsibilities, and exclusions, and ends with an identifying footer. Large files use stable section banners. Comments explain protocol layouts, ownership, platform behavior, or design reasons rather than restating individual statements.

Update the relevant document in `doc/` whenever a public option, shortcut, encoding, buffer size, ownership rule, or tested performance workflow changes.

## Validation before handoff

Run:

```text
make clean
make
make serial
make test
make perf
```

For RFB or threaded changes, also run the localhost benchmark and a real viewer session against both None and classic VNC authentication when applicable. Exercise resize, Fit and 1:1 presentation, full screen, view-only input suppression, pointer wheel, and clipboard exchange.

For presentation changes, record `FBGFX3_PROFILE=1` output from a steady interval and compare upload bytes, page changes, presentation count, GPU waits, and CPU profile samples. Update the dated findings document rather than replacing older measurements without their conditions.

<!-- end of developer-guide.md -->

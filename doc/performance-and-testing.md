# Performance and testing

## Choosing an encoding preference

| Connection or workload | Recommended preference | Reason |
| --- | --- | --- |
| Localhost video or animation | Raw | Avoids Hextile parsing and exposes the direct 32-bit copy path. |
| Fast wired LAN with high motion | Try Raw | Bandwidth is traded for lower decoder cost. |
| Lower-bandwidth remote GUI | Hextile default | Repeated colours and simple GUI regions use fewer bytes. |
| Large static desktop | Hextile default | Network savings normally outweigh its decoder bookkeeping. |

Loopback hosts `localhost`, `127.0.0.1`, and `::1` automatically prefer Raw. `--raw` makes the same choice for other hosts.

Scaling can dominate after Raw decoding becomes cheap. The default gfxlib3 build now uploads dirty remote rows to an opaque surface and uses `Gfx3SurfaceBlitScaled`; its scaling cost is GPU work. gfxlib2 and allocation failures retain the measured CPU scaler, where 1:1 uses row copies and Fit touches every visible destination pixel.

Presentation can dominate even when the decoder and scaler are keeping up. gfxlib3 profiling is therefore most useful when it records `present`, `page`, upload bytes, GPU waits, and render-thread execution together. On a gfxlib3 runtime that supports its built-in profiler, launch the viewer with:

```text
FBGFX3_PROFILE=1 ./fbvnc 127.0.0.1::5998 --raw --view-only
```

This environment option belongs to gfxlib3, not FB-VNC. A runtime without that diagnostic simply uses the normal viewer behavior.

## Built-in CPU fallback scaler benchmark

```text
make perf
```

This scales a deterministic 3840 by 2160 framebuffer into 1280 by 720 repeatedly. It reports elapsed time, milliseconds per frame, megapixels per second, and a checksum. The checksum makes the final framebuffer observable to the optimizer.

Use the same compiler, display backend, screen depth, and machine load when comparing revisions. Run several times and compare a median rather than one unusually fast or slow result.

## End-to-end Raw benchmark

Terminal 1:

```text
make perf-rfb-server
```

Terminal 2:

```text
./fbvnc 127.0.0.1::5999 --raw --view-only
```

The benchmark server negotiates a 1920 by 1080, 32-bit Raw session and sends 120 complete frames. It reports frames per second and payload MiB per second. The workload includes standard `OPEN TCP` transfer, viewer buffering, decoding, synchronization, and presentation rather than measuring the scaler alone.

The server accepts optional frame-count and start-delay arguments when invoked directly:

```text
./tests/perf_rfb_server 300 1000
```

The example sends 300 frames after a 1000 ms delay, which is useful when attaching a profiler.

## Correctness tests

```text
make test
```

| Test | Coverage |
| --- | --- |
| `test_des` | VNC password bit reversal and both DES challenge blocks against a known vector. |
| `test_scaler` | Fit dimensions, clipping, nearest-neighbour mapping, and one-to-one copies. |
| `test_server_parser` | Host names, displays, literal ports, IPv4, IPv6, defaults, and malformed values. |

The tests retain runtime checks through the same default compiler flags as the application.

## Performance design already present

- 64 KiB per-client receive cache for small RFB fields.
- Direct-to-framebuffer reads for full-width native Raw rectangles.
- 8 MiB threaded incoming ring, large enough for one 1080p 32-bit frame without wrapping.
- Separate communications and decoder workers.
- Narrow framebuffer critical section.
- Coalescing of completed threaded frames to at most 60 presentations per second.
- Hidden-page composition and conditional flips.
- One opaque gfxlib3 surface with dirty-row uploads and GPU nearest-neighbour scaling.
- One reusable image for the visible remote rectangle as the gfxlib2 and allocation-failure fallback.
- Batched gfxlib3 alpha points for omaGUI text instead of destination-pixel reads.
- One gfxlib3 presentation boundary per page exchange; the older gfxlib2 path retains its `ScreenSync` requirement.
- One-to-one row copy and a division-free scaled inner loop.
- Bounded two-millisecond idle waits instead of unbounded busy polling.

## Interpreting bottlenecks

High network throughput with low presentation rate usually points to surface upload, scaling, UI composition, or gfxlib page presentation. Low Raw throughput on localhost points to TCP transfer, receive-buffer copying, or decoder contention. Good Hextile bandwidth with high CPU use points to tile and subrectangle parsing.

A gfxlib3 profile with equal `present` and `page` counts is expected. Two `present` operations for each page exchange usually means an extra synchronization boundary has been reintroduced. Steady `download` bytes should remain zero. One download per frame normally means an omaGUI or application path has called `Point`, `Get`, or another CPU read after the scaled surface made the work page GPU-authoritative. Upload bytes should follow decoded dirty row height, not the complete local window.

The Info panel distinguishes threaded and serial sessions. Always record that state with performance results because the two pipelines have different scheduling behavior.

For a credible comparison, record:

- compiler version and flags;
- gfxlib selection;
- threaded or serial execution;
- remote framebuffer and local window dimensions;
- encoding order;
- frame count and content type;
- local or remote network path.

## Recorded optimization run

The [2026-08-27 performance findings](performance-findings-2026-08-27.md) preserve the exact development-machine conditions and paired measurements. Early changes raised steady localhost presentation from about 30 page changes per second to 52 to 55 and reduced CPU-image upload traffic. The later opaque-surface path held about 51 to 52 presentations/s while reducing steady upload to about 18.8 to 19.2 MiB/s for the demo's dirty bands and eliminating 132 to 146 MiB/s of work-page downloads. The same run found no mutex bottleneck: communications and decoding workers used only a few percent of a core.

<!-- end of performance-and-testing.md -->

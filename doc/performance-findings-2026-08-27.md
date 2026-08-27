# Performance findings, 2026-08-27

This document is the lab record for the localhost profiling and optimization pass performed with FB-VNC connected to `FB-VNC-SRV-LIB`. Results are preserved with their conditions so later work can distinguish a real improvement from a changed backend, resolution, or workload.

## Test system and workload

| Item | Value |
| --- | --- |
| Operating system | Linux 7.0.0-30-generic, x86-64 |
| Processor | Intel Core i5-1345U, 10 logical CPUs |
| Display | X11, 1366 x 768, 24-bit root window |
| Graphics | Intel Iris Xe, Mesa 26.0.8 |
| Compiler | FreeBASIC 1.20.3-1, `-O 2 -exx -w all` |
| Viewer | Threaded `-mt` build, gfxlib3 unless noted |
| Server | `FB-VNC-SRV-LIB` demo on `127.0.0.1::5998` |
| RFB mode | Raw, view only, localhost |
| Normal remote size | 800 x 600 |
| Normal viewer size | 1024 x 720 |

The animated server changes enough pixels to approximate video rather than a static desktop. Numbers below are steady one-second observations or complete benchmark runs. They are measurements on this system, not portable minimums.

## Server backend comparison

Run the reproducible comparison from the server-library directory:

```text
make profile-compare
```

Two complete runs produced:

| Backend | Capture ms/frame | Capture MPixels/s | Full Raw frames/s | Incremental frames/s |
| --- | ---: | ---: | ---: | ---: |
| gfxlib2, run A | 0.759 | 1213.96 | 231.22 | 298.75 |
| gfxlib3, run A | 1.736 | 530.92 | 178.28 | 201.88 |
| gfxlib2, run B | 0.657 | 1402.84 | 236.84 | 264.52 |
| gfxlib3, run B | 1.637 | 563.07 | 183.05 | 311.61 |

Both backends produced checksum `&h00A5781E`. Full Raw moved 421.88 MiB in every run. Incremental one-pixel updates moved 3.52 MiB.

The stable conclusions are:

- gfxlib2 SCREEN capture was 2.3 to 2.5 times faster;
- gfxlib2 full-frame Raw transport was 26 to 30 percent faster;
- the small incremental transport rate varied enough that neither backend has a credible advantage there;
- change detection reduced bytes by about 99.2 percent in its deliberately sparse workload.

For these reasons, the server library now builds gfxlib2 by default. `make gfx3` creates separately named gfxlib3 library, demo, and benchmark artifacts for applications that require that backend.

## Viewer presentation experiments

gfxlib3's `FBGFX3_PROFILE=1` output exposed page exchanges, presentations, uploads, render-thread time, and GPU waits. The command used was:

```text
FBGFX3_PROFILE=1 ./fbvnc 127.0.0.1::5998 --raw --view-only
```

| Configuration | Page changes/s | Presents/s | Upload MiB/s | Observation |
| --- | ---: | ---: | ---: | --- |
| Unthrottled gfxlib3 demo server | about 7 | not stable | not retained | The server submitted 320 to 390 local presents/s and starved useful capture/presentation work. |
| gfxlib2 server, old viewer flip | about 30 | about 60 | about 96.7 | `ScreenSync` and `ScreenSet` created two gfxlib3 presentation boundaries. |
| gfxlib2 server, one viewer boundary | 52 to 55 | 52 to 55 | 170.8 to 177.2 | Removing gfxlib3 `ScreenSync` nearly doubled completed page exchanges. |
| Reusable visible-rectangle image | 53 to 54 | 53 to 54 | 137.0 to 139.6 | Frame rate held while upload traffic fell roughly 20 percent. |

Upload traffic increased when page rate first increased because more complete frames were being shown. The reusable image comparison holds frame rate constant and is therefore the meaningful upload result.

The old renderer obtained `ScreenPtr`, scaled into the selected work page, and unlocked it. gfxlib3 then had to upload the complete externally writable page. The revised renderer scales into one cached 32-bit `ImageCreate` allocation and uses `Put ... PSet` for only the clipped remote rectangle.

The local gfxlib3 implementation deliberately treats a pointer returned by `ImageInfo` as externally writable. Its image cache performs an exact snapshot comparison before a cached `Put`, then reuses the same GPU allocation when pixels differ. Reusing one image avoids allocation churn, but the snapshot work remains visible in profiles.

## gfxlib3 surface scaler follow-up

The CPU profile above identified nearest-neighbour scaling as the largest viewer sample. The follow-up replaced the normal gfxlib3 image path with a remote-sized opaque surface from `fbgfx3.bi`. Each decoded rectangle contributes to mutex-protected dirty bounds. The main thread uploads complete affected row spans and calls `Gfx3SurfaceBlitScaled` with `GFX3_FILTER_NEAREST` into the aspect-fitted or one-to-one destination.

The first version revealed an ordering problem rather than a scaler problem. omaGUI antialiased text used `Point` to obtain each destination colour. Once a GPU transform had made the work page authoritative on the GPU, the next text pass downloaded that page. Moving the transform relative to the toolbar only moved the readback to the following frame.

| Surface configuration | Presents/s | Upload MiB/s | Download MiB/s | Render execute ms/s |
| --- | ---: | ---: | ---: | ---: |
| GPU scale followed by software alpha text | 47 to 52 | 36.6 to 40.5 | 132.2 to 146.3 | 787 to 850 |
| GPU scale plus batched alpha points | 51 to 52 | 18.8 to 19.2 | 0 | 429 to 497 |

The final omaGUI gfxlib3 branch builds one `Gfx3Point` packet per antialiased string and lets gfxlib3 blend it on the GPU. Its gfxlib2 branch remains the established `Point` plus `PSet` fallback. gfxlib alpha primitives use a 256 divisor while the old omaGUI software blend used 255, so partial alpha is advanced by one before submission; the difference from the old formula is bounded to one channel value. omaGUI's existing alpha-render smoke passes with both backends.

The animated demo changes a horizontal band rather than every row, which explains why final upload traffic is well below one complete 800 x 600 framebuffer per presentation. `Gfx3SurfaceUpload` copies `pitch * height` bytes into its command. Uploading full-width affected rows keeps that source region contiguous and avoids an out-of-bounds read from an interior x pointer on the last row. Dirty left and right bounds are retained for a future packed-rectangle experiment.

The one startup interval contained a single 2.8 MiB download while pages and resources were initialized. Every recorded steady interval reported zero reads, zero downloads, zero completion waits, and zero GPU-wait time.

## Desktop larger than the window

The server demo was resized live from 800 x 600 through 1000 x 700 to the display-limited 1200 x 768. The viewer accepted each DesktopSize update, replaced its opaque surface, and preserved complete fit scaling. With the viewer reduced to 640 x 480, the final GPU path recorded 46 to 49 presentations/s, 25.5 to 27.1 MiB/s upload, and zero download while fitting the 1200 x 768 desktop.

During the earlier reusable-image stage, the viewer was also reduced to 640 x
480 while serving an 800 x 600 remote desktop:

| Mode | Upload MiB/s | Presentations/s | Meaning |
| --- | ---: | ---: | --- |
| Fit | 57.2 to 58.3 | 53 to 54 | The image covered the fitted visible rectangle. |
| 1:1 with scrollbars | 61.8 to 63.0 | 53 to 54 | The image covered only the current viewport, not all 800 x 600 remote pixels. |

The slight 1:1 increase was expected because its visible clipped rectangle was
larger than the fitted rectangle. Upload did not jump to the full remote
framebuffer size, confirming that the CPU fallback excluded off-screen pixels.

## Thread and CPU observations

Before the reusable image change, a representative steady sample assigned about 56 percent of one core to the gfxlib3 worker and 41 percent to the viewer main thread. The communications and decoder workers together used about 2 percent. The gfxlib3 profile reported zero steady GPU-wait time. These observations reject mutex contention and TCP processing as the active frame limiter for this localhost Raw workload.

Paired gprof builds were also run for equal scheduled intervals against the same gfxlib2 server:

| Viewer backend | `backend_Flip` calls | Total sampled CPU seconds | Scaler self seconds |
| --- | ---: | ---: | ---: |
| gfxlib2 | 510 | 4.06 | 1.84 |
| gfxlib3 | 844 | 5.00 | 1.73 |

Profiling and startup/shutdown time perturb both counts, so this is a comparison rather than a frame-rate promise. gfxlib3 completed about 65 percent more presentations in the same scheduled run. The gfxlib2 viewer uses less total CPU only because it presents fewer frames. This is why gfxlib3 remains the viewer default and gfxlib2 is exposed only as `make gfx2`.

The gfxlib3 flat profile attributed its largest self samples to:

- nearest-neighbour scaling, 34.6 percent;
- gfxlib compatibility pixel writes used by omaGUI text, 17.0 percent;
- image snapshot storage after writable `ImageInfo`, 13.4 percent;
- compatibility shadow rectangle mirroring, 9.4 percent.

Network and decoder functions did not accumulate measurable flat-profile samples in this run. The remaining work is in scaling and gfxlib/omaGUI compatibility rendering, not the worker queues.

## gfxlib2 and Haiku readiness follow-up

The final gfxlib2 viewer was run against the final gfxlib2 server demo using a
threaded localhost Raw session. The remote SCREEN was resized live to 1200 x
700 and the viewer to 1024 x 600. Ten one-second `pidstat` samples produced the
following process CPU averages, where 100 percent represents one complete CPU
core:

| Viewer mode | Average CPU | Rendering work |
| --- | ---: | --- |
| Fit | 26.9 percent | CPU nearest-neighbour scale into the fitted visible image |
| 1:1 | 18.8 percent | CPU row copies for the visible scrollable viewport |

Fit preserved the complete larger desktop. The 1:1 path created working
horizontal and vertical scrollbars and excluded off-screen pixels from its
staging image. Windowed and full-screen transitions retained two-page
presentation; full screen removed both bars, and Ctrl-Alt-Shift-F returned to
the saved window mode. omaGUI's options and clipboard overlays rendered
correctly through the gfxlib2 software alpha path.

The gfxlib2 viewer also completed the 120-frame, 1920 x 1080 full-frame Raw
transport workload. The server supplied 136.7 frames/s and 1081.5 MiB/s on
loopback without a protocol or decoder failure. This number measures how fast
the server could deliver complete frames into the viewer pipeline; it is not a
claim that gfxlib2 presented 136.7 frames/s.

For the planned Haiku port, FreeBASIC 1.20.3 compiled all seven viewer modules
through its `haiku-x86_64` target front end in both threaded and serial forms.
The generated sources contained no gfxlib3 commands. A native Haiku executable
could not be linked or run on the Linux development host because no Haiku
sysroot and linker are installed, so native window behavior remains the first
port milestone rather than an assumed result.

## Server demo findings

The original demo redrew and copied its local gfx page as fast as its loop could run. That made a local display demonstration compete with VNC capture. Its animation is now capped at 60 FPS while protocol pumping still runs every two milliseconds.

A resizable gfxlib SCREEN reallocates its pages before posting `EVENT_WINDOW_RESIZE`. Calling `ScreenRes` again from that event was redundant and could stall gfxlib2. The demo now lets gfxlib own the resize; the server library observes the new `ScreenInfo` dimensions and sends DesktopSize normally.

`ScreenCopy` could also block the gfxlib2 demo during occlusion or disconnect. The default demo now uses one CPU framebuffer page and brackets each complete draw with `ScreenLock` and `ScreenUnlock`. This removes the local page copy and saves one framebuffer allocation. The optional gfxlib3 demo retains two pages and `ScreenCopy` so the backend comparison remains available. The library itself remains independent of the application's page count.

## Retained changes

1. Default the server library and demo to gfxlib2, with separately named gfxlib3 targets.
2. Add `make profile-compare` for repeatable paired server measurements.
3. Limit demo drawing to 60 FPS without limiting network pumping.
4. Let resizable SCREEN events stand instead of calling `ScreenRes` again.
5. Use a lock-batched single page in the default gfxlib2 demo.
6. Remove the redundant gfxlib3 `ScreenSync` before page exchange.
7. Reuse one clipped 32-bit presentation image and retain a direct-render fallback.
8. Add `make gfx2` for viewer portability and comparison, while retaining gfxlib3 as the default.
9. Track decoded dirty bounds and upload affected row spans to one opaque gfxlib3 surface.
10. Use `Gfx3SurfaceBlitScaled` for the default viewer's Fit and 1:1 presentation.
11. Gate omaGUI antialiased text through batched gfxlib3 alpha points so it does not read the work page back.

## Remaining candidates

The current evidence suggests two possible later experiments:

- cache static toolbar and status chrome so unchanged controls are not rebuilt for every video frame;
- pack narrow dirty rectangles into a bounded staging buffer and compare the saved surface upload bytes with the added CPU copy.

These have not been applied. Each changes a reusable subsystem or API assumption and needs its own correctness and cross-backend measurements.

## Validation completed

- Viewer DES, scaler, and server-parser tests passed.
- omaGUI's alpha-render smoke passed in both gfxlib3 and gfxlib2 builds after the alpha-point gate was added.
- Server pixel-format, capture-depth, TCP integration, clipboard/input, public-bind, and authentication tests passed with the final default gfxlib2 build. The separately named gfxlib3 capture and transport benchmarks also completed.
- Fit scaling with a 1200 x 768 remote desktop inside a 640 x 480 viewer, live DesktopSize changes, fullscreen behavior, and repeated resize/disconnect were exercised with the paired applications.
- Clipboard transport remains covered by the server integration test; the presentation changes do not alter the clipboard path or omaGUI portability gate.

<!-- end of performance-findings-2026-08-27.md -->

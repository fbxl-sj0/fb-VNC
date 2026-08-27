# FB-VNC documentation

This directory contains the detailed documentation for the portable FreeBASIC VNC viewer. The project-level [README](../README.md) is the short overview. These documents explain normal use, the implementation, protocol boundaries, performance behavior, and maintenance expectations.

## Start here

| Goal | Document |
| --- | --- |
| Build the viewer on a FreeBASIC target | [Building and portability](building-and-portability.md) |
| Connect and use the graphical interface | [User guide](user-guide.md) |
| Automate startup or inspect every option | [Command-line reference](command-line.md) |
| Understand RFB compatibility and security | [Protocol and security](protocol-and-security.md) |
| Understand the serial and threaded pipelines | [Architecture](architecture.md) |
| Measure or tune the viewer | [Performance and testing](performance-and-testing.md) |
| Review the measured optimization record | [Performance findings, 2026-08-27](performance-findings-2026-08-27.md) |
| Diagnose a connection, display, or input problem | [Troubleshooting](troubleshooting.md) |
| Extend an encoding, UI action, or worker path | [Developer guide](developer-guide.md) |

## Project boundaries

FB-VNC is intentionally built from standard FreeBASIC 1.20.3 facilities:

- `OPEN TCP` supplies the client transport.
- gfxlib3 supplies the resizable window, framebuffer, and events.
- the standard FreeBASIC runtime supplies optional threads, mutexes, and conditions.
- the vendored omaGUI source supplies portable controls drawn into gfxlib pages.
- the project supplies its own RFB parser, framebuffer decoders, scaler, and classic VNC DES operation.

There are no native socket calls, native clipboard calls, platform window APIs, zlib, or JPEG dependencies. This boundary is responsible for both the broad target coverage and the deliberate protocol omissions described in [Protocol and security](protocol-and-security.md).

## Related server library

The sibling [FB-VNC-SRV-LIB](../../FB-VNC-SRV-LIB/README.md) project performs the opposite role. It presents an application's current gfxlib `SCREEN` framebuffer to a VNC viewer and exposes remote input through a portable event queue. Its detailed documentation is in [FB-VNC-SRV-LIB/doc](../../FB-VNC-SRV-LIB/doc/README.md).

<!-- end of doc/README.md -->

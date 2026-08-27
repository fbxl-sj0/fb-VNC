# Protocol and security

## RFB version negotiation

The viewer accepts server protocol banners for RFB major version 3 and minor version 3 or newer. It negotiates the highest implemented version not newer than the server:

| Server advertises | Viewer uses |
| --- | --- |
| 3.3 through 3.6 | 3.3 |
| 3.7 | 3.7 |
| 3.8 or newer 3.x | 3.8 |

A malformed banner, a different major version, or a version older than 3.3 fails the connection before framebuffer allocation.

The banner, security exchange, `ClientInit`, `ServerInit`, pixel format, encoding list, and first framebuffer request are completed serially. Optional worker threads start only after this bounded negotiation is complete.

## Security types

The implemented security types are:

| RFB type | Name | Viewer behavior |
| --- | --- | --- |
| 1 | None | Selected when no password was supplied and the server offers it. |
| 2 | VNC Authentication | Selected when offered and a password was supplied. Required when it is the only supported choice. |

For RFB 3.3, the server chooses one type. For RFB 3.7 and 3.8, the viewer examines the offered list. Unsupported-only lists fail with a clear message.

Classic VNC authentication reads a 16-byte challenge, derives the protocol DES key by reversing the bits of each of the first eight password bytes, encrypts the two challenge halves, sends the 16-byte response, and checks `SecurityResult`. The DES implementation is internal and tested against a known response vector.

## Security limitations

Classic VNC authentication is retained for compatibility, not confidentiality:

- only eight password bytes are effective;
- the challenge-response construction is old and unsuitable as modern password protection;
- the session is not encrypted after authentication;
- framebuffer pixels, key events, pointer events, and clipboard text cross the network in clear form.

Use the viewer only on a network suitable for this threat model or through a secure tunnel established outside the viewer. The project does not claim that type 2 authentication makes a public VNC service safe.

Supplying `--password` also exposes the value to local process-list tools and possibly shell history. The graphical password field avoids command-line exposure, but it does not change the wire-security limitations.

## Pixel format

After `ServerInit`, the viewer requests one fixed true-colour format:

| Field | Value |
| --- | --- |
| Bits per pixel | 32 |
| Depth | 24 |
| Endian | little-endian |
| True colour | yes |
| Red, green, blue maximum | 255 each |
| Red, green, blue shift | 16, 8, 0 |

The internal numeric pixel representation is `0x00RRGGBB`. The unused high byte is padding.

## Framebuffer encodings

| Encoding | Support | Notes |
| --- | --- | --- |
| Raw | Decoded | Has a direct full-width copy path on compatible little-endian hosts. |
| CopyRect | Decoded | Handles overlapping source and destination regions. |
| RRE | Decoded | Validates every subrectangle and count before applying it. |
| CoRRE | Decoded | Uses the compact one-byte coordinate layout. |
| Hextile | Decoded | Supports Raw tiles and background, foreground, coloured, and uncoloured subrectangles. |
| Tight | Not negotiated | Requires compression and optional JPEG support outside standard FreeBASIC. |
| Zlib and ZRLE | Not negotiated | Require a DEFLATE implementation. |
| JPEG | Not negotiated | Requires an image codec. |

The advertised preference is Hextile, CopyRect, RRE, CoRRE, then Raw for an ordinary remote host. `--raw`, the dialog option, and recognized loopback hosts put Raw first.

## Pseudo-encodings

| Pseudo-encoding | Behavior |
| --- | --- |
| DesktopSize | Reallocates the framebuffer and requests a complete new image. |
| LastRect | Ends an update whose rectangle count was a sentinel. |
| XCursor | Validates and consumes the cursor payload. |
| RichCursor | Validates and consumes the cursor payload. |
| PointerPos | Accepts the position notification without moving a native cursor. |

Cursor shapes are consumed to preserve stream alignment, but gfxlib's local pointer remains visible. This avoids native cursor creation and pointer-warping APIs.

## Server-to-client messages

The viewer accepts `FramebufferUpdate`, `SetColourMapEntries`, `Bell`, and `ServerCutText`. Colour-map data is consumed but unused because the negotiated framebuffer is true colour. A bell sets the status indicator. Clipboard text is stored for the portable Clipboard panel.

Unknown server message types terminate the session because RFB has no generic length field with which to skip an unknown message safely.

## Client-to-server messages

The viewer sends:

- `SetPixelFormat` and `SetEncodings` during initialization;
- full and incremental `FramebufferUpdateRequest` messages;
- `KeyEvent` using X11 keysyms represented by RFB;
- `PointerEvent`, including wheel buttons 4 and 5;
- `ClientCutText` through the portable clipboard panel.

Only one framebuffer request is outstanding. If Refresh is selected while an incremental request is pending, the viewer records that a full request is needed and sends it immediately after the current update completes.

## Defensive limits

Server-controlled dimensions, strings, rectangle counts, subrectangles, and payload calculations are checked before allocation or pointer arithmetic. Principal limits include a 512 MiB framebuffer, 1 MiB desktop name, 16 MiB clipboard, and 16,777,216 RRE subrectangles. A valid value can still fail if the target cannot supply the requested memory.

<!-- end of protocol-and-security.md -->

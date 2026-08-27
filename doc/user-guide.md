# User guide

## Starting the viewer

Run `./fbvnc` with no arguments to open the connection dialog. Enter a server address, optionally enter a classic VNC password, select the desired options, and press Enter or click Connect.

The connection fields accept the same display and literal-port forms commonly used by TightVNC:

| Input | Meaning |
| --- | --- |
| `server.example` | TCP port 5900 on the named host. |
| `server.example:2` | VNC display 2, which maps to TCP port 5902. |
| `server.example::5999` | Literal TCP port 5999. |
| `:1` | Display 1 on the default host, `127.0.0.1`. |
| `::1` | Bare IPv6 loopback host on TCP port 5900. |
| `[::1]:2` | IPv6 loopback, display 2. |
| `[::1]::5999` | IPv6 loopback, literal TCP port 5999. |

Brackets are required when an IPv6 address also has a display or port suffix. Commas and equals signs are rejected because `OPEN TCP` reserves them in its connection specification.

## Connection options

| Option | Behavior |
| --- | --- |
| Share the session | Sends a shared `ClientInit` flag. Clear it to request an exclusive session. The server decides how exclusivity is enforced. |
| View only | Receives and displays updates but suppresses keyboard, pointer, wheel, and outgoing clipboard messages. |
| Scale remote desktop to fit | Preserves the remote aspect ratio and fits the entire desktop into the available viewer area. |
| Show the session toolbar | Displays the TightVNC-style controls in windowed mode. F8 can change this later. |
| Prefer Raw encoding | Puts Raw first in the encoding list. Loopback connections do this automatically. |

If a password is provided and the server offers classic VNC authentication, the viewer selects it. If the password is empty and the server offers None security, the viewer selects None. Classic VNC uses only the first eight password bytes.

## Session toolbar

| Control | Action |
| --- | --- |
| New | Disconnects and returns to the connection dialog. |
| Options | Opens the in-session view-only, scaling, and toolbar options. |
| Refresh | Requests a non-incremental full framebuffer update. |
| Ctrl-Esc | Sends a complete Ctrl-Escape key sequence to the remote system. |
| Ctrl-Alt-Del | Sends a complete Ctrl-Alt-Delete key sequence to the remote system. |
| Full screen | Enters or leaves full-screen mode. |
| Fit / 1:1 | Toggles scale-to-fit and one-remote-pixel-per-local-pixel presentation. |
| Control / View | Toggles view-only mode for the active session. |
| Clipboard | Opens the portable clipboard panel. |
| Info | Shows desktop size, protocol version, encoding preference, transport, and execution mode. |

The toolbar can extend beyond a very narrow window. Resize the window if the later controls are not visible.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| F8 | Hides or restores the session toolbar. |
| Ctrl-Alt-Shift-F | Toggles full screen. Either Shift key is accepted. |
| Esc in a dialog | Closes the overlay. In the initial connection dialog it exits the viewer. |
| Enter in the connection dialog | Connects. |
| Tab in the connection dialog | Moves between the server and password fields. |

Ctrl-Alt-Shift-F belongs to the viewer and is not delivered to the remote desktop. The viewer releases any already-sent modifiers before changing display mode so the remote machine does not retain a stuck Ctrl, Alt, or Shift state.

## Scaling and large desktops

Fit mode uses aspect-preserving nearest-neighbour scaling. Unused space is centered around the remote image. Pointer coordinates are mapped back into remote framebuffer coordinates, so input remains aligned after resizing the local window.

In 1:1 mode, the viewer never crops the stored remote framebuffer. If the remote desktop is larger than the available window, horizontal and vertical scrollbars appear. Click a scrollbar track to move to the corresponding part of the remote desktop. Switching back to Fit resets both scroll offsets.

When the server sends DesktopSize, the viewer reallocates its internal framebuffer, updates the layout, and requests a complete image at the new dimensions.

## Full-screen behavior

Full screen gives the remote desktop the complete local display. Both the toolbar and status bar are removed. Leaving full screen restores the saved resizable window dimensions and the windowed toolbar preference.

## Clipboard

The clipboard panel is deliberately application-local. It does not read or write the operating system clipboard.

When a server sends `ServerCutText`, the text becomes the draft shown the next time Clipboard is opened. Edit the single-line field and press Enter or click Send to transmit `ClientCutText`. Outgoing clipboard transfer is disabled in view-only mode.

This design keeps clipboard behavior available on targets without a native clipboard API and keeps omaGUI host clipboard behavior intact in programs that do not define `OMAGUI_PORTABLE_ONLY`.

## Status and connection information

The windowed status bar reports the remote desktop name and size, negotiated RFB version, completed update count, view-only state, threaded or serial execution, and receipt of a bell message.

The Info panel provides the same connection facts in a stable layout. It is also the easiest way to confirm whether a target is using the worker pipeline or the portable serial fallback.

<!-- end of user-guide.md -->

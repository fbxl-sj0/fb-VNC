# Command-line reference

## Syntax

```text
fbvnc [server] [options]
```

A positional server value starts the connection immediately. `--server VALUE` does the same. Without an immediate-connect argument, the graphical connection dialog opens with `127.0.0.1` pre-filled.

## Options

| Option | Default | Effect |
| --- | --- | --- |
| `--server VALUE` | `127.0.0.1` | Sets the server field and connects immediately. |
| `--password VALUE` | empty | Supplies the classic VNC password. |
| `--view-only` | off | Suppresses keyboard, pointer, wheel, and outgoing clipboard messages. |
| `--exclusive` | off | Clears the shared-session flag sent during initialization. |
| `--no-scale` | off | Starts in 1:1 mode instead of scale-to-fit mode. |
| `--raw` | off | Prefers Raw before Hextile. Loopback uses Raw regardless. |
| `--hide-toolbar` | off | Starts with the windowed toolbar hidden. F8 restores it. |
| `--connect` | off | Connects immediately using the current values, including defaults. |
| `--help`, `-h`, `/?` | | Prints usage and exits successfully. |

Unknown options and options missing a required value exit with status 2. A normal GUI exit returns status 0. Failure to create the gfxlib window returns status 1.

## Examples

Open the dialog:

```text
./fbvnc
```

Connect to display 1:

```text
./fbvnc server.example:1
```

Connect to a literal port in view-only 1:1 mode:

```text
./fbvnc server.example::5999 --view-only --no-scale
```

Prefer Raw on a trusted fast LAN:

```text
./fbvnc --server 192.0.2.25::5900 --raw
```

Connect to IPv6 display 2:

```text
./fbvnc "[2001:db8::25]:2"
```

Connect immediately to the default `127.0.0.1::5900` server:

```text
./fbvnc --connect
```

## Argument order

Arguments are processed from left to right. Later options update the current configuration. Any non-option argument becomes the server value and enables immediate connection. For predictable scripts, use one server argument.

## Password exposure

`--password` is convenient for automated testing, but command-line arguments may be visible to process-list tools and shell history. Prefer the masked graphical password field for interactive use.

Classic VNC authentication is not encryption. The password has eight effective bytes, and all later framebuffer, input, and clipboard traffic remains readable on the network.

<!-- end of command-line.md -->

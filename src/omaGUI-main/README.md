# omaGUI

omaGUI is a GUI toolkit for FreeBASIC programs that use the built-in gfxlib
graphics system. It provides a classic desktop widget set, ordered child
windows, modal dialogs, editable text, drawing primitives, and 28 imported
graphic-shape types through one public include.

The current implementation includes the complete widget and graphics surface.
The line, rectangle, circle, curve, graphic-shape, scaled text, aligned text,
alpha, and embedded multi-font APIs are all present in `omaGUI.bi`.

## Requirements

- A recent FreeBASIC compiler with gfxlib support
- The repository directory, or `omaGUI.bi`, `src`, and `assets`, available on
  the compiler include path
- No separate GUI framework

## Quick start

Define `OMAGUI_IMPLEMENTATION` in exactly one source file, then include the
master header:

```freebasic
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

backend_Init(800, 600, 0, BACKEND_WINDOW_RESIZABLE)
gui_Init()

Dim helloButton As Widget Ptr
helloButton = button_Create("hello", "Hello", 20, 20, 100, 30)
gui_AddWidget helloButton

Do
    backend_Clear RGB(240, 240, 240)
    gui_UpdateAll
    gui_RenderAll
    backend_Flip

    If gui_ButtonPressed("hello") Then Exit Do
    If MultiKey(FB.SC_ESCAPE) Then Exit Do

    Sleep 10, 1
Loop

backend_Exit
```

From the repository root, build it with:

```powershell
fbc app.bas
```

If a program has several source files, the other files include `omaGUI.bi`
without defining `OMAGUI_IMPLEMENTATION`.

## Included controls

- Buttons, labels, checkboxes, grouped radio buttons, scrollbars, and listboxes
- Single-line and multiline textboxes with selection, clipboard commands,
  bounded undo/redo history, word wrapping, wheel scrolling, and configurable
  vertical scrollbars
- Draggable and closable child windows with parent-bound content, client
  clipping, focus, pointer capture, modal routing, and front-to-back ordering
- File-open, file-save, and confirmation dialogs
- Popup menus with per-item callbacks or a shared selection handler
- Line, rectangle, circle, and quadratic curve widgets
- All 28 imported graphic-shape kinds, including opt-in interactive buttons,
  choices, text fields, calendars, trends, and alarm lists
- Solid and gradient fills, line widths, corner radii, clipping, path points,
  embedded fonts, alignment, scaling, and alpha compositing
- 32-bit, 16-bit, 8-bit, 4-bit, and true black-and-white 1-bit display modes
- Parent-relative anchors for layouts that react to gfxlib resize and maximize
  events

## Run the demo

```powershell
fbc demo.bas
.\demo.exe
```

The demo exercises every widget family and all 28 graphic-shape kinds. It also
shows real combo and date popup menus, interactive imported controls,
multiline scrollbar policies, mouse-wheel input, overlapping closable windows,
resizable anchors, all color depths, and a live 0-to-255 alpha control over a
checkerboard.

Native border resizing is requested from gfxlib. The GUI reacts to every size
change gfxlib reports, including maximize. A platform or gfxlib build that does
not provide draggable native borders cannot be made resizable by the widget
layer itself.

Alpha blending is available in 16-bit and 32-bit modes. True color uses the
documented integer blend directly, while 16-bit output is quantized by the
display format. Indexed 1-bit, 4-bit, and 8-bit modes map colors through their
active palettes and render alpha drawing as opaque palette output.

## Test and lint

Each `.bas` file under `tests` is a standalone FreeBASIC program. Build and run the
suite from the repository root. The project is also checked with the local
fblint executable:

```powershell
Get-ChildItem tests -Filter *.bas | ForEach-Object {
    $testExe = $_.FullName -replace '\.bas$', '.exe'
    fbc $_.FullName -x $testExe
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($_.Name)" }
    & $testExe
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $($_.Name)" }
}

& 'C:\Nextcloud\games\newjrpg\fblint\fb_linter.exe' .
```

See [docs/MANUAL.md](docs/MANUAL.md) for the complete programming model, API
guide, widget behavior, limits, and test inventory.

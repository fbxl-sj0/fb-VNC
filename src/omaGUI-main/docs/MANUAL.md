# omaGUI Library Manual

This manual describes the public API and behavior of the current omaGUI
implementation. The declarations in `omaGUI.bi` and the public `.bi` files are
the final authority for exact function signatures.

## 1. Architecture

omaGUI has three layers:

1. The gfxlib backend owns the display surface, color mapping, drawing, fonts,
   clipping, snapshots, and raw input polling.
2. The GUI manager owns registered widgets, hierarchy, layout, window order,
   focus, pointer capture, modal routing, update order, and render order.
3. Individual widget modules own control-specific state and behavior.

Application code creates widgets and registers them with the GUI manager. The
manager owns registered widget pointers and calls each widget's update, render,
and destroy callbacks. Removing a parent recursively removes its descendants.

## 2. Building a program

### 2.1 Master include

Define `OMAGUI_IMPLEMENTATION` in exactly one program source file before
including `omaGUI.bi`:

```freebasic
#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"
```

Other source files can include `omaGUI.bi` without the definition. Defining it
in more than one compilation unit would duplicate the implementation.

The master include exposes every backend and widget module, including the
primitive widgets and all graphic-shape APIs.

### 2.2 Initialization and frame loop

Call `backend_Init` before `gui_Init`. A normal frame clears the draw target,
updates the GUI once, renders it once, and flips the gfxlib pages:

```freebasic
backend_Init 800, 600, 0, BACKEND_WINDOW_RESIZABLE
gui_Init

Do
    backend_Clear RGB(236, 236, 236)
    gui_UpdateAll
    gui_RenderAll
    backend_Flip

    If MultiKey(FB.SC_ESCAPE) Then Exit Do
    Sleep 10, 1
Loop

backend_Exit
```

`gui_UpdateAll` polls input and the live drawable size. Do not call
`input_Update` separately in the normal application loop.

### 2.3 Widget creation and ownership

Constructors return a heap-allocated `Widget Ptr`. Register each top-level
widget and each child with `gui_AddWidget`. Then use `gui_SetParent` to bind a
child to its owner:

```freebasic
Dim toolWindow As Widget Ptr
Dim runButton As Widget Ptr

toolWindow = subwindow_Create("tools", "Tools", 40, 40, 260, 180)
runButton = button_Create("run", "Run", 12, 14, 80, 28)

gui_AddWidget toolWindow
gui_AddWidget runButton
gui_SetParent runButton, toolWindow
```

Child `x` and `y` values are local to the parent's client area. The manager
stores the resolved screen position in `ax` and `ay`. Parent cycles and overly
deep invalid hierarchies are rejected.

`gui_AddWidget` makes duplicate names unique by adding a numeric suffix.
`gui_AddGeneratedWidget` is an importer fast path that skips this scan, so its
caller must supply unique names.

Use `gui_RemoveWidget(name)` to destroy a widget tree. Do not delete registered
widgets directly. `gui_ResetForTest` destroys every registered widget and
clears manager state.

## 3. Graphics backend

### 3.1 Display creation

```freebasic
backend_Init(width, height, headless, windowFlags, colorDepth)
```

The last four arguments have defaults. Important values are:

| Setting | Values |
| --- | --- |
| Window flags | `BACKEND_WINDOW_FIXED`, `BACKEND_WINDOW_RESIZABLE` |
| Color depths | `BACKEND_COLOR_DEPTH_MONOCHROME`, `BACKEND_COLOR_DEPTH_16_COLOR`, `BACKEND_COLOR_DEPTH_256_COLOR`, `BACKEND_COLOR_DEPTH_HIGH_COLOR`, `BACKEND_COLOR_DEPTH_TRUE_COLOR` |

The `headless` argument remains part of the API for deterministic call sites.
The gfxlib backend still creates a software screen because it is both the draw
target and the source of compatible input state.

If gfxlib rejects the requested low-depth mode during initialization, omaGUI
falls back to 32-bit color. `backend_GetColorDepth` reports the active depth.
`backend_SetColorDepth` returns nonzero on success and makes a best effort to
restore the previous mode after a driver failure.

### 3.2 Resize behavior

`BACKEND_WINDOW_RESIZABLE` requests a resizable gfxlib surface.
`backend_GetSize` reports the current drawable size, and `gui_UpdateAll`
automatically updates the GUI viewport from it. `backend_IsResizable` reports
whether the active gfxlib screen accepted the request.

The GUI reacts to resize and maximize events reported by gfxlib. It does not
emulate native border dragging. If borders cannot be dragged, that behavior is
in the installed gfxlib build or platform driver.

### 3.3 Color depths and palettes

| Constant | Depth | Mapping |
| --- | ---: | --- |
| `BACKEND_COLOR_DEPTH_TRUE_COLOR` | 32 | Direct RGB color |
| `BACKEND_COLOR_DEPTH_HIGH_COLOR` | 16 | Driver high-color mode |
| `BACKEND_COLOR_DEPTH_256_COLOR` | 8 | 216-color RGB cube plus 40 neutral grays |
| `BACKEND_COLOR_DEPTH_16_COLOR` | 4 | Conventional 16-color VGA palette |
| `BACKEND_COLOR_DEPTH_MONOCHROME` | 1 | Black or white from a weighted luma threshold |

The 1-bit mode is deliberately black and white. The backend maps requested RGB
colors through the active indexed palette, so the demo remains readable instead
of depending on driver-specific palette defaults.

### 3.4 Drawing primitives

The direct backend primitives are:

- `backend_PSet` and `backend_PSetAlpha`
- `backend_Line` and alpha-aware `backend_LineEx`
- `backend_Rect` and alpha-aware `backend_RectEx`
- `backend_Circle`
- `backend_Curve`, a quadratic Bezier through two endpoints and one control
  point

`gui_DrawLine`, `gui_DrawRect`, `gui_DrawCircle`, and `gui_DrawCurve` provide
matching high-level helpers.

Alpha values are clamped to the range 0 through 255. A value of 0 draws
nothing, and 255 is opaque. Pixel blending is available in 16-bit and 32-bit
modes. Indexed modes render nonzero alpha through the active palette rather
than blending palette indices.

### 3.5 Text, fonts, scaling, and alignment

The embedded font identifiers are:

- `BACKEND_FONT_DEFAULT`
- `BACKEND_FONT_ARIAL_10_REGULAR`
- `BACKEND_FONT_ARIAL_12_BOLD`

The printing API includes default-font, selected-font, scaled, alpha, aligned,
and aligned-scaled variants. Horizontal alignment uses
`BACKEND_ALIGN_LEFT`, `BACKEND_ALIGN_CENTER`, or `BACKEND_ALIGN_RIGHT`.
Vertical alignment uses `BACKEND_ALIGN_TOP`, `BACKEND_ALIGN_MIDDLE`, or
`BACKEND_ALIGN_BOTTOM`.

Use the matching `backend_GetTextWidth*` and `backend_GetTextHeight*`
functions when laying out text. Scale factors smaller than one are treated as
one.

```freebasic
backend_PrintAlignedScaledAlpha _
    20, 20, 240, 60, RGB(30, 70, 130), "Status", _
    BACKEND_FONT_ARIAL_12_BOLD, _
    BACKEND_ALIGN_CENTER, BACKEND_ALIGN_MIDDLE, _
    2, 2, 192
```

### 3.6 Clipping and snapshots

`backend_SetClip(x, y, w, h)` pushes an intersected clip rectangle.
`backend_ResetClip()` pops one level. This stack behavior allows nested parent
and control clips. Every push must have a matching reset. The current stack is
bounded at 128 levels.

`backend_SaveSnapshot(filename)` writes a 24-bit BMP from a framebuffer with at
least three bytes per pixel. It returns without writing when that format cannot
be read safely from the active surface.

### 3.7 Theme colors

`backend_Init` initializes `current_theme` with `theme_InitClassic`.
Applications can replace its public color fields or use `theme_GetColor` with
the semantic `GUI_COLOR_*` identifiers. The built-in widgets read the shared
theme during rendering, so a later color change applies without reconstructing
them.

## 4. GUI manager

### 4.1 Base widget state

Every `Widget` contains a name, local rectangle, resolved rectangle, visibility
and enabled flags, focus state, hierarchy links, widget-private data, layout
state, and update/render/destroy callbacks.

Applications normally use constructors and public accessors instead of editing
widget-private data. Directly setting `visible`, `enabled`, `x`, `y`, `w`, or
`h` is supported when a dynamic layout needs it. The manager recalculates
effective visibility, enabled state, absolute coordinates, and clips each
frame.

### 4.2 Window order and input routing

Registry order is paint order. A click on a window or any descendant brings
the complete window tree to the front. `gui_BringToFront` provides the same
operation explicitly.

Only the topmost eligible widget sees a pointer event. A held pointer is
captured by the widget where the press started, which keeps drags and text
selections stable. Keyboard input is routed only to `gui_GetFocus()`.
`gui_SetFocus` can change focus explicitly.

Children are clipped and hit-tested inside their parent's client area. A
subwindow title bar remains owned by the window, not by its children. Hiding,
disabling, moving, closing, raising, or removing a parent applies coherently to
its complete tree.

### 4.3 Modal roots

`gui_SetModalRoot(root)` limits input to one widget tree while leaving the
desktop visible behind it. `gui_ClearModalRoot` releases it, and
`gui_IsModalOpen` reports the state. The built-in file and confirmation dialogs
set and clear modal state as part of their lifecycle.

### 4.4 Anchors

Call `gui_SetAnchors(widget, flags)` after the widget has its intended starting
rectangle. Its container is the parent client area, or the GUI viewport for a
top-level widget.

| Horizontal anchors | Result when the container width changes |
| --- | --- |
| Left and right | Stretch width |
| Right only | Move with the right edge |
| Left only | Keep the starting local rectangle |
| Neither | Stay centered relative to the original layout |

The same rules apply to top and bottom. `GUI_ANCHOR_ALL` stretches on both
axes. `gui_ResetAnchors` returns a widget to ordinary parent-relative layout.
Tests can set a deterministic viewport with `gui_SetViewportSize` and read it
with `gui_GetViewportSize`.

## 5. Standard widgets

### 5.1 Buttons

```freebasic
Declare Sub onRun(ByVal clicked As Widget Ptr)

Dim runButton As Widget Ptr
runButton = button_Create("run", "Run", 20, 20, 90, 28, @onRun)
gui_AddWidget runButton
```

The optional callback receives the clicked widget pointer. Applications can
also poll `gui_ButtonPressed(name)`, which reports the button's completed press
state.

### 5.2 Labels, checkboxes, and radio buttons

`label_Create` makes noninteractive text. `checkbox_Create` stores a boolean
`checked` state. `radiobox_Create` stores a group identifier and selection
state; selecting one radio button clears the other registered buttons in that
group.

These simple controls expose their state through `CheckBoxData` and
`RadioBoxData` in their public headers.

### 5.3 Scrollbars

`scrollbar_Create(name, x, y, w, h, maxValue, pageSize, vertical)` creates a
horizontal or vertical scrollbar. The `ScrollBarData` value is always bounded
to its valid range. Listboxes and multiline textboxes own integrated vertical
scrollbar widgets, so applications should not register those internal bars
separately.

### 5.4 Listboxes

Listboxes hold up to `LISTBOX_MAX_ITEMS`, currently 1024. They support pointer
selection, Up and Down keys, an integrated scrollbar, and mouse-wheel scrolling
while the pointer is over the list.

Use `listbox_AddItem`, `listbox_Clear`, `listbox_GetSelectedIndex`, and
`listbox_GetSelectedItem`. The selected index is zero-based and is `-1` when
nothing is selected.

### 5.5 Popup menus

Menus hold up to `MENU_MAX_ITEMS`, currently 32. Two callback styles are
available:

- `menu_AddItem` can attach `Sub(ByVal index As Integer)` to each item.
- `menu_SetSelectionHandler` installs one
  `Sub(ByVal context As Any Ptr, ByVal index As Integer)` handler for the menu.

The shared handler is useful for generated combo and date popups because it can
carry the owning control as its context. `menu_ClearItems` resets the current
choices. A click outside a visible menu dismisses it.

### 5.6 Textboxes

```freebasic
Dim editor As Widget Ptr

editor = textbox_Create( _
    "editor", "Multiline text", 12, 12, 420, 240, _
    -1, -1, TEXTBOX_SCROLLBAR_ALWAYS _
)
gui_AddWidget editor
```

The `m` and `ww` constructor arguments enable multiline mode and word wrapping.
The final argument selects one of three vertical scrollbar policies:

| Policy | Behavior |
| --- | --- |
| `TEXTBOX_SCROLLBAR_NONE` | Never show a vertical bar |
| `TEXTBOX_SCROLLBAR_AUTO` | Show it only when visual rows overflow |
| `TEXTBOX_SCROLLBAR_ALWAYS` | Reserve the gutter and show a disabled bar when content fits |

The auto policy is the default. Use `textbox_SetVerticalScrollbar` to change it
and `textbox_GetVerticalScrollbarMode` to query it.

Multiline rendering, cursor movement, hit testing, selection, and scrolling
share the same wrapped visual-row model. The wheel scrolls three visual rows at
a time while content overflows. Dragging the thumb provides direct access to
the complete document.

Textboxes support pointer selection, Shift selection, Home, End, arrow keys,
Backspace, Delete, Return in multiline mode, and a right-click Copy, Cut, and
Paste menu. They also support these shortcuts:

- Ctrl+A: select all
- Ctrl+C: copy
- Ctrl+X: cut
- Ctrl+V: paste
- Ctrl+Z: undo
- Ctrl+Y: redo

Undo and redo history is local to each textbox. It is bounded to 16 entries and
2,097,152 stored bytes. Repeated typing and deletion are grouped. Use
`textbox_SetText(widget, text, resetHistory)` for programmatic replacement,
and pass nonzero for `resetHistory` when the old editing history must not apply
to the new document.

The plain-text clipboard accepts at most `CLIPBOARD_MAX_TEXT_BYTES`, currently
2,097,152 bytes.

### 5.7 Subwindows

`subwindow_Create` creates a draggable child window with a title bar. The final
constructor argument controls whether the close button is available and
defaults to enabled.

Without an application callback, close hides the complete window tree.
`subwindow_CloseRequested` reports that state, and `subwindow_Reopen` restores
and raises the hidden tree. `subwindow_SetClosable` changes close availability.

`subwindow_SetCloseHandler` installs a
`Sub(ByVal window As Widget Ptr)` callback when the application needs to save,
confirm, or remove the window itself.

### 5.8 File and confirmation dialogs

The file APIs are:

- `filedialog_Create` for an open dialog in the current directory
- `filedialog_CreateAtPath` for an open dialog at an explicit path
- `filedialog_CreateSaveAtPath` for save mode and an initial filename

`confirmdialog_Create` creates a modal message with a configurable confirmation
label and a Cancel option.

`filedialog_GetResultState` and `confirmdialog_GetResultState` return:

| Value | Meaning |
| ---: | --- |
| `0` | Still pending |
| `1` | Accepted or confirmed |
| `-1` | Cancelled or closed |

`filedialog_GetSelectedFile` returns a path only after acceptance. Poll the
result from the application loop, copy any needed result, then remove the
dialog root with `gui_RemoveWidget`. The manager destroys its descendants and
releases the modal root.

## 6. Drawing widgets

The following constructors make registry-managed drawing elements:

- `linewidget_Create`
- `rectwidget_Create`
- `circlewidget_Create`
- `curvewidget_Create`

They participate in parent positioning, clipping, visibility, and paint order
like other widgets. The curve is quadratic and stores a control point relative
to its first endpoint.

## 7. Imported graphic shapes

Graphic shapes represent imported HMI elements and lightweight custom drawing.
They are static by default. Call `graphicshape_SetInteractive` only for shapes
that should participate in routed input.

### 7.1 Shape kinds

The supported numeric identifiers are stable:

| Value | Constant | Value | Constant |
| ---: | --- | ---: | --- |
| 1 | `GUI_SHAPE_LINE` | 15 | `GUI_SHAPE_CONNECTOR` |
| 2 | `GUI_SHAPE_RECTANGLE` | 16 | `GUI_SHAPE_CONTROL` |
| 3 | `GUI_SHAPE_ROUNDED_RECTANGLE` | 17 | `GUI_SHAPE_CHECKBOX` |
| 4 | `GUI_SHAPE_ELLIPSE` | 18 | `GUI_SHAPE_COMBOBOX` |
| 5 | `GUI_SHAPE_POLYLINE` | 19 | `GUI_SHAPE_LISTBOX` |
| 6 | `GUI_SHAPE_POLYGON` | 20 | `GUI_SHAPE_EDITBOX` |
| 7 | `GUI_SHAPE_CURVE` | 21 | `GUI_SHAPE_CALENDAR` |
| 8 | `GUI_SHAPE_TEXT` | 22 | `GUI_SHAPE_DATE_TIME_PICKER` |
| 9 | `GUI_SHAPE_TEXTBOX` | 23 | `GUI_SHAPE_RADIO_BUTTON_GROUP` |
| 10 | `GUI_SHAPE_BUTTON` | 24 | `GUI_SHAPE_TREND_CONTROL` |
| 11 | `GUI_SHAPE_IMAGE` | 25 | `GUI_SHAPE_TREND_PEN` |
| 12 | `GUI_SHAPE_ARC` | 26 | `GUI_SHAPE_MULTI_PEN_TREND` |
| 13 | `GUI_SHAPE_PIE` | 27 | `GUI_SHAPE_ALARM_CLIENT` |
| 14 | `GUI_SHAPE_CHORD` | 28 | `GUI_SHAPE_EMBEDDED_SYMBOL` |

### 7.2 Construction and render options

Use `graphicshape_Create` for basic stroke, fill, and label properties.
`graphicshape_CreateStyled*` adds common style and text arguments.
`graphicshape_CreateWithOptions` accepts the complete
`GraphicShapeRenderOptions` structure. Initialize that structure with
`graphicshape_DefaultOptions` before overriding fields.

Options include:

- stroke, fill, gradient, and text colors
- solid, vertical gradient, horizontal gradient, and horizontal edge-gradient
  fill modes
- line width and rounded-corner radius
- object, stroke, and fill alpha
- embedded font, horizontal alignment, vertical alignment, and text fitting
- clipping to the shape bounds
- up to eight positioned gradient stops

Paths accept up to 16 points through `graphicshape_SetPathPoint`.
`graphicshape_SetRenderOptions` replaces the complete option set. Dedicated
setters are available for alpha, gradient, gradient stops, clipping, corner
radius, and path points.

Object alpha multiplies the component alpha. For example, object alpha 128 and
fill alpha 128 produce an effective fill alpha of approximately 64. Text uses
object alpha. `graphicshape_SetOutlineAlpha` is an alias for stroke alpha.

`graphicshape_RenderWithOptions` draws directly without allocating or
registering a widget. It is intended for importers that already own their shape
records.

### 7.3 Interactive imported controls

```freebasic
Declare Sub onModeChanged(ByVal changed As Widget Ptr)

Dim importedCombo As Widget Ptr
importedCombo = graphicshape_Create( _
    "mode", GUI_SHAPE_COMBOBOX, 12, 12, 150, 28, _
    RGB(40, 40, 40), RGB(245, 245, 245), -1, "Mode" _
)

graphicshape_AddItem importedCombo, "Manual"
graphicshape_AddItem importedCombo, "Automatic"
graphicshape_SetInteractive importedCombo, -1, @onModeChanged
gui_AddWidget importedCombo
```

The change callback receives the owning `Widget Ptr`. Read its new state with
the public accessors. `graphicshape_GetChangeCount` also supports deterministic
polling. Programmatic setters do not need applications to manipulate private
shape storage.

| Shape family | Input behavior |
| --- | --- |
| Button | Pointer press and Enter activation |
| Checkbox | Pointer or Enter toggle |
| Textbox and editbox | Focused text input and Backspace |
| Combo box and date-time picker | Real popup option menu, wheel, Up, Down, and Enter |
| Listbox and alarm client | Pointer row selection, wheel, Up, and Down |
| Calendar | Pointer day selection |
| Radio-button group | Pointer, wheel, Up, and Down choice selection |
| Control and trend controls | Pointer and keyboard value changes from 0 through 100 |

Combo and date popups are separate menu widgets, bound to the same owning
window tree. They open upward when there is not enough room below, close after
selection, and dismiss on an outside click. Use
`graphicshape_IsDropdownOpen` when application logic needs to inspect this
state.

Choice controls hold up to `GRAPHICSHAPE_MAX_ITEMS`, currently 16. Editable
shape text is limited to `GRAPHICSHAPE_MAX_INPUT_LENGTH`, currently 256
characters. Use `graphicshape_AddItem`, `graphicshape_ClearItems`,
`graphicshape_GetSelectedIndex`, `graphicshape_GetSelectedItem`,
`graphicshape_SetText`, `graphicshape_GetText`, `graphicshape_SetValue`, and
`graphicshape_GetValue`.

Image and embedded-symbol kinds currently provide generic placeholder
rendering. Decoding external image payloads, galaxy files, animation rules, and
application command policy remain importer or application responsibilities.

## 8. Demo guide

Build and run the demo from the repository root:

```powershell
fbc demo.bas
.\demo.exe
```

The demo intentionally covers the complete widget surface and the major
backend display modes:

- every standard widget and primitive drawing widget
- all 28 graphic-shape kinds
- functional imported buttons, checkboxes, text input, lists, calendars,
  choices, radio groups, control values, trends, and alarm lists
- visible combo and date popup menus
- three multiline textbox scrollbar policies and mouse-wheel scrolling
- overlapping windows with order, parent binding, clipping, close, and reopen
- a resizable anchored layout
- 32-bit, 16-bit, 8-bit, 4-bit, and black-and-white 1-bit modes
- a live 0-to-255 gallery alpha control over a checkerboard

Press Escape to leave the demo. When testing window order, click a window or a
child to raise its complete tree. When testing alpha, use a 16-bit or 32-bit
mode so background blending is visible.

## 9. Deterministic input tests

The input module can replace physical input for one test process:

- `input_MockMouse(x, y, buttons, wheelDelta)`
- `input_MockText(text)`
- `input_MockKey(keycode, state)`
- `input_ResetForTest()`

The mocks feed the same manager routing path as ordinary input. A test normally
calls `gui_UpdateAll` after changing mock state, then releases the mouse or key
and updates again.

The test programs cover backend colors and alpha, resizable layout, registry
ownership, modal routing, file dialogs, textbox editing and history, wrapped
text scrolling, window order and clipping, restored primitive widgets, and
interactive graphic shapes.

To compile and run every test:

```powershell
Get-ChildItem tests -Filter *.bas | ForEach-Object {
    $testExe = $_.FullName -replace '\.bas$', '.exe'
    fbc $_.FullName -x $testExe
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($_.Name)" }
    & $testExe
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $($_.Name)" }
}
```

Run the project linter with the configured local installation:

```powershell
& 'C:\Nextcloud\games\newjrpg\fblint\fb_linter.exe' .
```

The font generator is a separate build check:

```powershell
fbc tools\font_gen.bas
```

## 10. Current limits

- Native border resize support depends on gfxlib and its platform driver.
- Indexed color modes use palette mapping and do not blend alpha channels.
- Clip nesting is bounded at 128 levels.
- Listboxes hold 1024 items, menus 32 items, and graphic-shape choices 16
  items.
- Graphic-shape paths hold 16 points and gradients hold eight stops.
- Textbox history and clipboard text are bounded to avoid unbounded allocation.
- Imported image decoding, galaxy parsing, animation evaluation, and
  application-specific commands are outside this library layer.

## 11. Public API index

This index is a compact map to the declarations. Optional arguments and exact
types remain in the named public header.

### Backend and input

- Lifecycle and display: `backend_Init`, `backend_Exit`, `backend_GetSize`,
  `backend_IsResizable`, `backend_GetColorDepth`, and
  `backend_SetColorDepth`
- Frame output: `backend_Clear`, `backend_Flip`, and `backend_SaveSnapshot`
- Primitives: `backend_PSet`, `backend_PSetAlpha`, `backend_Line`,
  `backend_LineEx`, `backend_Rect`, `backend_RectEx`, `backend_Circle`, and
  `backend_Curve`
- Text: `backend_Print`, `backend_PrintScaled`, `backend_PrintFont`,
  `backend_PrintFontAlpha`, `backend_PrintScaledFont`,
  `backend_PrintScaledFontAlpha`, `backend_PrintAligned`,
  `backend_PrintAlignedAlpha`, `backend_PrintAlignedScaled`, and
  `backend_PrintAlignedScaledAlpha`
- Measurement: `backend_GetTextWidth`, `backend_GetTextWidthScaled`,
  `backend_GetTextWidthFont`, `backend_GetTextWidthScaledFont`,
  `backend_GetTextHeight`, `backend_GetTextHeightScaled`,
  `backend_GetTextHeightFont`, and `backend_GetTextHeightScaledFont`
- Clip stack: `backend_SetClip` and `backend_ResetClip`
- Input state: `input_MouseX`, `input_MouseY`, `input_MouseButtons`,
  `input_MouseWheel`, `input_KeyPressed`, and `input_PollTextInput`
- Test input: `input_MockMouse`, `input_MockKey`, `input_MockText`, and
  `input_ResetForTest`
- Theme and clipboard: `theme_InitClassic`, `theme_GetColor`,
  `clipboard_GetText`, and `clipboard_SetText`

`input_Update` and `input_SetDispatchMask` are public for custom manager and
test integration. Ordinary omaGUI applications let `gui_UpdateAll` call them.
`font_init_pointers` is assembled by the backend lifecycle and should not be
needed by application code.

### GUI manager

- Registry: `gui_Init`, `gui_ResetForTest`, `gui_AddWidget`,
  `gui_AddGeneratedWidget`, `gui_RemoveWidget`, and `gui_FindWidget`
- Hierarchy and order: `gui_SetParent` and `gui_BringToFront`
- Focus and modal state: `gui_SetFocus`, `gui_GetFocus`, `gui_SetModalRoot`,
  `gui_ClearModalRoot`, and `gui_IsModalOpen`
- Layout: `gui_SetViewportSize`, `gui_GetViewportSize`, `gui_SetAnchors`, and
  `gui_ResetAnchors`
- Frame dispatch: `gui_UpdateAll` and `gui_RenderAll`
- Drawing helpers: `gui_DrawLine`, `gui_DrawRect`, `gui_DrawCircle`, and
  `gui_DrawCurve`
- Control helpers: `gui_ButtonPressed` and `gui_DeselectRadioGroup`

### Standard widgets

- Constructors: `button_Create`, `textbox_Create`, `checkbox_Create`,
  `radiobox_Create`, `label_Create`, `scrollbar_Create`, `listbox_Create`,
  `subwindow_Create`, `menu_Create`, `linewidget_Create`,
  `rectwidget_Create`, `circlewidget_Create`, and `curvewidget_Create`
- Textbox state: `textbox_ClearHistory`, `textbox_BeginEdit`,
  `textbox_EndEditGroup`, `textbox_Undo`, `textbox_Redo`, `textbox_SetText`,
  `textbox_SetVerticalScrollbar`, and `textbox_GetVerticalScrollbarMode`
- Listbox state: `listbox_AddItem`, `listbox_Clear`,
  `listbox_GetSelectedIndex`, and `listbox_GetSelectedItem`
- Window state: `subwindow_SetCloseHandler`, `subwindow_SetClosable`,
  `subwindow_CloseRequested`, and `subwindow_Reopen`
- Menu state: `menu_AddItem`, `menu_ClearItems`, and
  `menu_SetSelectionHandler`
- File dialogs: `filedialog_Create`, `filedialog_CreateAtPath`,
  `filedialog_CreateSaveAtPath`, `filedialog_GetSelectedFile`, and
  `filedialog_GetResultState`
- Confirmation dialogs: `confirmdialog_Create` and
  `confirmdialog_GetResultState`

The `*_Render`, `*_Update`, and `*_Destroy` declarations are widget lifecycle
entry points used by constructors and the manager. Applications normally do
not call them directly.

### Graphic shapes

- Construction: `graphicshape_DefaultOptions`, `graphicshape_Create`,
  `graphicshape_CreateStyled`, `graphicshape_CreateStyledText`,
  `graphicshape_CreateStyledTextColor`,
  `graphicshape_CreateStyledTextColorFit`, and
  `graphicshape_CreateWithOptions`
- Direct drawing: `graphicshape_RenderWithOptions`
- Rendering state: `graphicshape_SetRenderOptions`,
  `graphicshape_SetCornerRadius`, `graphicshape_SetClipToBounds`,
  `graphicshape_SetObjectAlpha`, `graphicshape_SetStrokeAlpha`,
  `graphicshape_SetOutlineAlpha`, `graphicshape_SetFillAlpha`,
  `graphicshape_SetFillGradient`, `graphicshape_SetFillGradientStops`, and
  `graphicshape_SetPathPoint`
- Input state: `graphicshape_SetInteractive`, `graphicshape_IsInteractive`,
  `graphicshape_SetValue`, `graphicshape_GetValue`, `graphicshape_SetText`,
  `graphicshape_GetText`, `graphicshape_ClearItems`, `graphicshape_AddItem`,
  `graphicshape_GetSelectedIndex`, `graphicshape_GetSelectedItem`,
  `graphicshape_GetChangeCount`, and `graphicshape_IsDropdownOpen`

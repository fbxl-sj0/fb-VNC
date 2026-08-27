/'
    Project: omaGUI Toolkit Demo
    ----------------------------

    File: demo.bas

    Purpose:

        Present the complete public widget set in a resizable gfxlib window.

    Responsibilities:

        - demonstrate parent-relative reactive layouts
        - exercise editable text, history, selection, lists, and callbacks
        - launch modal open, save, and confirmation dialogs
        - display every imported graphic-shape kind and primitive widget
        - expose live 0-to-255 alpha compositing against a checkerboard
        - switch safely among true-color and indexed-color display modes

    This file intentionally does NOT contain:

        - application persistence
        - platform-specific graphics calls
        - test-only input injection
'/

#lang "fb"

#If Defined(__FB_WIN32__)
#cmdline "-s gui"
#EndIf

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Const DEMO_INITIAL_WIDTH As Integer = 1180
Const DEMO_INITIAL_HEIGHT As Integer = 700
Const DEMO_DIALOG_NONE As Integer = 0
Const DEMO_DIALOG_OPEN As Integer = 1
Const DEMO_DIALOG_SAVE As Integer = 2
Const DEMO_DIALOG_CONFIRM As Integer = 3
Const DEMO_ALPHA_DEFAULT As Integer = 192
Const DEMO_ALPHA_MAX As Integer = 255
Const DEMO_ALPHA_PATTERN_SIZE As Integer = 12
Const DEMO_GALLERY_BACKDROP_X As Integer = 8
Const DEMO_GALLERY_BACKDROP_Y As Integer = 26
Const DEMO_GALLERY_BACKDROP_WIDTH As Integer = 394
Const DEMO_GALLERY_BACKDROP_HEIGHT As Integer = 506

/'
    Demo module state

    Button and menu callbacks need access to the currently displayed dialog,
    editor, popup menu, and status line. The demo owns these pointers, and the
    GUI registry owns the objects to which they point.
'/
Dim Shared As Widget Ptr demo_ActiveDialog
Dim Shared As Integer demo_ActiveDialogKind
Dim Shared As Widget Ptr demo_AlphaLabel
Dim Shared As Widget Ptr demo_AlphaScrollbar
Dim Shared As Widget Ptr demo_ControlsPanel
Dim Shared As Widget Ptr demo_Editor
Dim Shared As Widget Ptr demo_EditorPanel
Dim Shared As Widget Ptr demo_FeatureList
Dim Shared As Widget Ptr demo_GalleryShapes( _
    GUI_SHAPE_LINE To GUI_SHAPE_EMBEDDED_SYMBOL _
)
Dim Shared As Widget Ptr demo_GraphicsPanel
Dim Shared As Integer demo_LastListSelection
Dim Shared As Integer demo_LastAlphaValue
Dim Shared As Widget Ptr demo_PopupMenu
Dim Shared As Integer demo_RequestedDepth
Dim Shared As Widget Ptr demo_StatusLabel

Declare Function demo_GetShapeLabel( _
    ByVal shapeKind As Integer _
) As String

' -------------------------------------------------------------------------
' Status and callback helpers
' -------------------------------------------------------------------------

Private Sub demo_SetStatus(ByVal message As String)
    Dim As LabelData Ptr labelData

    If demo_StatusLabel = 0 OrElse demo_StatusLabel->data = 0 Then Exit Sub

    labelData = Cast(LabelData Ptr, demo_StatusLabel->data)
    labelData->text = message
End Sub


Private Sub demo_OnDepthButton(ByVal w As Widget Ptr)
    Dim As ButtonData Ptr buttonData

    If w = 0 OrElse w->data = 0 Then Exit Sub

    buttonData = Cast(ButtonData Ptr, w->data)
    demo_RequestedDepth = ValInt(buttonData->text)
End Sub


Private Sub demo_OnUndo(ByVal w As Widget Ptr)
    If demo_Editor <> 0 AndAlso textbox_Undo(demo_Editor) Then
        demo_SetStatus "Editor: undo completed"
    Else
        demo_SetStatus "Editor: nothing to undo"
    End If
End Sub


Private Sub demo_OnRedo(ByVal w As Widget Ptr)
    If demo_Editor <> 0 AndAlso textbox_Redo(demo_Editor) Then
        demo_SetStatus "Editor: redo completed"
    Else
        demo_SetStatus "Editor: nothing to redo"
    End If
End Sub


Private Sub demo_OnMenuItem(ByVal selectedIndex As Integer)
    Select Case selectedIndex
    Case 0
        demo_SetStatus "Popup callback: first command selected"
    Case 1
        demo_SetStatus "Popup callback: second command selected"
    Case Else
        demo_SetStatus "Popup callback: menu dismissed"
    End Select
End Sub


Private Sub demo_OnShowMenu(ByVal w As Widget Ptr)
    If w = 0 OrElse demo_PopupMenu = 0 Then Exit Sub

    demo_PopupMenu->x = w->ax
    demo_PopupMenu->y = w->ay + w->h
    demo_PopupMenu->visible = -1
    gui_BringToFront demo_PopupMenu
End Sub


Private Sub demo_OnRestoreWindows(ByVal w As Widget Ptr)
    subwindow_Reopen demo_ControlsPanel
    subwindow_Reopen demo_EditorPanel
    subwindow_Reopen demo_GraphicsPanel
    demo_SetStatus "All demo windows restored; click one to bring it forward"
End Sub


Private Sub demo_OpenDialog( _
    ByVal dialogKind As Integer, _
    ByVal sourceButton As Widget Ptr _
)
    Dim As Integer dialogHeight
    Dim As Integer dialogWidth
    Dim As Integer screenHeight
    Dim As Integer screenWidth

    If demo_ActiveDialog <> 0 Then
        demo_SetStatus "Close the active modal dialog first"
        Exit Sub
    End If

    backend_GetSize screenWidth, screenHeight

    If dialogKind = DEMO_DIALOG_CONFIRM Then
        dialogWidth = 400
        dialogHeight = 150
    Else
        dialogWidth = 400
        dialogHeight = 340
    End If

    Select Case dialogKind
    Case DEMO_DIALOG_OPEN
        demo_ActiveDialog = filedialog_CreateAtPath( _
            "demo_open_dialog", _
            (screenWidth - dialogWidth) \ 2, _
            (screenHeight - dialogHeight) \ 2, _
            CurDir _
        )
    Case DEMO_DIALOG_SAVE
        demo_ActiveDialog = filedialog_CreateSaveAtPath( _
            "demo_save_dialog", _
            (screenWidth - dialogWidth) \ 2, _
            (screenHeight - dialogHeight) \ 2, _
            CurDir, "example.bas" _
        )
    Case DEMO_DIALOG_CONFIRM
        demo_ActiveDialog = confirmdialog_Create( _
            "demo_confirm_dialog", _
            "Confirm action", _
            "This demonstrates modal input isolation.", _
            (screenWidth - dialogWidth) \ 2, _
            (screenHeight - dialogHeight) \ 2, _
            "Confirm" _
        )
    End Select

    If demo_ActiveDialog <> 0 Then
        demo_ActiveDialogKind = dialogKind
        gui_AddWidget demo_ActiveDialog
        demo_SetStatus "Modal dialog opened"
    End If
End Sub


Private Sub demo_OnOpenFile(ByVal w As Widget Ptr)
    demo_OpenDialog DEMO_DIALOG_OPEN, w
End Sub


Private Sub demo_OnSaveFile(ByVal w As Widget Ptr)
    demo_OpenDialog DEMO_DIALOG_SAVE, w
End Sub


Private Sub demo_OnConfirm(ByVal w As Widget Ptr)
    demo_OpenDialog DEMO_DIALOG_CONFIRM, w
End Sub


Private Sub demo_OnGraphicInput(ByVal w As Widget Ptr)
    Dim As GraphicShapeData Ptr shapeData
    Dim As String stateText

    If w = 0 OrElse w->data = 0 Then Exit Sub
    shapeData = Cast(GraphicShapeData Ptr, w->data)

    Select Case shapeData->shape_kind
    Case GUI_SHAPE_TEXTBOX, GUI_SHAPE_EDITBOX
        stateText = "text = " & graphicshape_GetText(w)
    Case GUI_SHAPE_BUTTON
        stateText = "button activated"
    Case GUI_SHAPE_CHECKBOX
        stateText = IIf(graphicshape_GetValue(w) <> 0, "checked", "cleared")
    Case GUI_SHAPE_COMBOBOX, GUI_SHAPE_LISTBOX, _
         GUI_SHAPE_DATE_TIME_PICKER, GUI_SHAPE_RADIO_BUTTON_GROUP, _
         GUI_SHAPE_ALARM_CLIENT
        stateText = "selection = " & graphicshape_GetSelectedItem(w)
    Case GUI_SHAPE_CALENDAR
        stateText = "day = " & graphicshape_GetValue(w)
    Case GUI_SHAPE_CONTROL, GUI_SHAPE_TREND_CONTROL
        stateText = "value = " & graphicshape_GetValue(w)
    Case Else
        stateText = "value = " & graphicshape_GetValue(w)
    End Select

    demo_SetStatus "Gallery " & demo_GetShapeLabel(shapeData->shape_kind) & _
        ": " & stateText
End Sub


' -------------------------------------------------------------------------
' Widget construction helpers
' -------------------------------------------------------------------------

Private Function demo_AddChild( _
    ByVal child As Widget Ptr, _
    ByVal parent As Widget Ptr, _
    ByVal anchors As UInteger = GUI_ANCHOR_NONE _
) As Widget Ptr
    If child = 0 Then Return 0

    gui_AddWidget child
    gui_SetParent child, parent

    If anchors <> GUI_ANCHOR_NONE Then gui_SetAnchors child, anchors

    Return child
End Function


Private Function demo_GetShapeLabel(ByVal shapeKind As Integer) As String
    Select Case shapeKind
    Case GUI_SHAPE_LINE               : Return "Line"
    Case GUI_SHAPE_RECTANGLE          : Return "Rect"
    Case GUI_SHAPE_ROUNDED_RECTANGLE  : Return "Round"
    Case GUI_SHAPE_ELLIPSE            : Return "Ellipse"
    Case GUI_SHAPE_POLYLINE           : Return "Polyline"
    Case GUI_SHAPE_POLYGON            : Return "Polygon"
    Case GUI_SHAPE_CURVE              : Return "Curve"
    Case GUI_SHAPE_TEXT               : Return "Text"
    Case GUI_SHAPE_TEXTBOX            : Return "Textbox"
    Case GUI_SHAPE_BUTTON             : Return "Button"
    Case GUI_SHAPE_IMAGE              : Return "Image"
    Case GUI_SHAPE_ARC                : Return "Arc"
    Case GUI_SHAPE_PIE                : Return "Pie"
    Case GUI_SHAPE_CHORD              : Return "Chord"
    Case GUI_SHAPE_CONNECTOR          : Return "Connect"
    Case GUI_SHAPE_CONTROL            : Return "Control"
    Case GUI_SHAPE_CHECKBOX           : Return "Check"
    Case GUI_SHAPE_COMBOBOX           : Return "Combo"
    Case GUI_SHAPE_LISTBOX            : Return "List"
    Case GUI_SHAPE_EDITBOX            : Return "Edit"
    Case GUI_SHAPE_CALENDAR           : Return "Calendar"
    Case GUI_SHAPE_DATE_TIME_PICKER   : Return "Date"
    Case GUI_SHAPE_RADIO_BUTTON_GROUP : Return "Radio"
    Case GUI_SHAPE_TREND_CONTROL      : Return "Trend"
    Case GUI_SHAPE_TREND_PEN          : Return "Pen"
    Case GUI_SHAPE_MULTI_PEN_TREND    : Return "Multi"
    Case GUI_SHAPE_ALARM_CLIENT       : Return "Alarm"
    Case GUI_SHAPE_EMBEDDED_SYMBOL    : Return "Symbol"
    End Select

    Return "Shape"
End Function


Private Sub demo_RenderAlphaBackdrop(ByVal w As Widget Ptr)
    Dim As ULong cellColor
    Dim As Integer cellHeight
    Dim As Integer cellWidth

    If w = 0 Then Exit Sub

    /'
        A checkerboard gives partially transparent pixels two visibly
        different destinations. A flat panel would only make alpha look like
        a lighter fill and would not demonstrate actual compositing clearly.
    '/
    For cellY As Integer = 0 To w->h - 1 Step DEMO_ALPHA_PATTERN_SIZE
        cellHeight = DEMO_ALPHA_PATTERN_SIZE
        If cellY + cellHeight > w->h Then cellHeight = w->h - cellY

        For cellX As Integer = 0 To w->w - 1 Step DEMO_ALPHA_PATTERN_SIZE
            cellWidth = DEMO_ALPHA_PATTERN_SIZE
            If cellX + cellWidth > w->w Then cellWidth = w->w - cellX

            If ((cellX \ DEMO_ALPHA_PATTERN_SIZE) + _
                (cellY \ DEMO_ALPHA_PATTERN_SIZE)) Mod 2 = 0 Then
                cellColor = RGB(245, 245, 245)
            Else
                cellColor = RGB(190, 190, 190)
            End If

            backend_Rect w->ax + cellX, w->ay + cellY, _
                cellWidth, cellHeight, cellColor, 1
        Next cellX
    Next cellY
End Sub


Private Function demo_CreateAlphaBackdrop() As Widget Ptr
    Dim As Widget Ptr backdrop = New Widget

    backdrop->name = "gallery_alpha_backdrop"
    backdrop->x = DEMO_GALLERY_BACKDROP_X
    backdrop->y = DEMO_GALLERY_BACKDROP_Y
    backdrop->w = DEMO_GALLERY_BACKDROP_WIDTH
    backdrop->h = DEMO_GALLERY_BACKDROP_HEIGHT
    backdrop->visible = -1
    backdrop->enabled = -1
    backdrop->render = @demo_RenderAlphaBackdrop
    Return backdrop
End Function


Private Sub demo_AddShapeGallery(ByVal parent As Widget Ptr)
    Dim As Integer columnIndex
    Dim As ULong fillColor
    Dim As GraphicShapeRenderOptions options
    Dim As Integer rowIndex
    Dim As Integer shapeKind
    Dim As Widget Ptr shapeWidget
    Dim As ULong strokeColor
    Dim As Integer stopPositions(1 To 3)
    Dim As ULong stopColors(1 To 3)

    demo_AddChild demo_CreateAlphaBackdrop(), parent

    For shapeKind = GUI_SHAPE_LINE To GUI_SHAPE_EMBEDDED_SYMBOL
        columnIndex = (shapeKind - 1) Mod 4
        rowIndex = (shapeKind - 1) \ 4
        strokeColor = RGB(28, 56 + (shapeKind * 5) Mod 160, 120)
        fillColor = RGB( _
            70 + (shapeKind * 29) Mod 150, _
            90 + (shapeKind * 17) Mod 140, _
            100 + (shapeKind * 11) Mod 130 _
        )

        graphicshape_DefaultOptions options, shapeKind
        options.stroke_clr = strokeColor
        options.fill_clr = fillColor
        options.fill_gradient_clr = RGB(245, 245, 255)
        options.text_clr = RGB(10, 10, 10)
        options.filled = -1
        options.fill_mode = (shapeKind - 1) Mod 4
        options.line_width = 2
        options.object_alpha = 255
        options.stroke_alpha = 255
        options.fill_alpha = 220
        options.font_id = BACKEND_FONT_ARIAL_10_REGULAR
        options.text_h_align = BACKEND_ALIGN_CENTER
        options.text_v_align = BACKEND_ALIGN_MIDDLE
        options.text_fit_width = 0
        If shapeKind = GUI_SHAPE_TEXT Then options.text_fit_width = -1
        options.corner_radius = 9
        options.clip_to_bounds = -1

        shapeWidget = graphicshape_CreateWithOptions( _
            "gallery_shape_" & shapeKind, _
            12 + (columnIndex * 96), _
            30 + (rowIndex * 74), _
            82, 54, options, demo_GetShapeLabel(shapeKind) _
        )
        demo_AddChild shapeWidget, parent
        demo_GalleryShapes(shapeKind) = shapeWidget

        Select Case shapeKind
        Case GUI_SHAPE_POLYLINE, GUI_SHAPE_POLYGON, GUI_SHAPE_CONNECTOR
            graphicshape_SetPathPoint shapeWidget, 1, 2, 42
            graphicshape_SetPathPoint shapeWidget, 2, 20, 5
            graphicshape_SetPathPoint shapeWidget, 3, 52, 45
            graphicshape_SetPathPoint shapeWidget, 4, 79, 8
        End Select

        If shapeKind = GUI_SHAPE_ROUNDED_RECTANGLE Then
            stopPositions(1) = 0
            stopPositions(2) = 5000
            stopPositions(3) = 10000
            stopColors(1) = RGB(30, 90, 210)
            stopColors(2) = RGB(120, 220, 255)
            stopColors(3) = RGB(245, 250, 255)
            graphicshape_SetFillGradientStops _
                shapeWidget, 3, stopPositions(), stopColors()
        End If

        Select Case shapeKind
        Case GUI_SHAPE_TEXTBOX
            graphicshape_SetText shapeWidget, "Type: "
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_BUTTON
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_CONTROL
            graphicshape_SetValue shapeWidget, 50
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_CHECKBOX
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_COMBOBOX
            graphicshape_AddItem shapeWidget, "Low"
            graphicshape_AddItem shapeWidget, "Medium"
            graphicshape_AddItem shapeWidget, "High"
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_LISTBOX
            graphicshape_AddItem shapeWidget, "One"
            graphicshape_AddItem shapeWidget, "Two"
            graphicshape_AddItem shapeWidget, "Three"
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_EDITBOX
            graphicshape_SetText shapeWidget, "Edit: "
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_CALENDAR
            graphicshape_SetValue shapeWidget, 12
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_DATE_TIME_PICKER
            graphicshape_AddItem shapeWidget, "Aug 12"
            graphicshape_AddItem shapeWidget, "Aug 13"
            graphicshape_AddItem shapeWidget, "Aug 14"
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_RADIO_BUTTON_GROUP
            graphicshape_AddItem shapeWidget, "First"
            graphicshape_AddItem shapeWidget, "Second"
            graphicshape_AddItem shapeWidget, "Third"
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_TREND_CONTROL
            graphicshape_SetValue shapeWidget, 50
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case GUI_SHAPE_ALARM_CLIENT
            graphicshape_AddItem shapeWidget, "Alarm A"
            graphicshape_AddItem shapeWidget, "Alarm B"
            graphicshape_AddItem shapeWidget, "Alarm C"
            graphicshape_SetInteractive shapeWidget, -1, @demo_OnGraphicInput
        Case Else
            ' Pure drawing elements remain intentionally pointer-transparent.
        End Select
    Next shapeKind

    demo_AddChild _
        linewidget_Create( _
            "primitive_line", 15, 545, 92, 570, RGB(210, 30, 30) _
        ), parent
    demo_AddChild _
        rectwidget_Create( _
            "primitive_rect", 112, 540, 60, 36, RGB(20, 155, 70), 0 _
        ), parent
    demo_AddChild _
        circlewidget_Create( _
            "primitive_circle", 218, 538, 18, RGB(25, 70, 220), -1 _
        ), parent
    demo_AddChild _
        curvewidget_Create( _
            "primitive_curve", 266, 575, 315, 526, 374, 566, _
            RGB(190, 30, 185) _
        ), parent
End Sub


Private Sub demo_BuildControlsPanel(ByVal panel As Widget Ptr)
    Dim As Widget Ptr listWidget

    demo_AddChild label_Create( _
        "depth_label", "Color depth (backend-managed):", 12, 32 _
    ), panel

    demo_AddChild button_Create( _
        "depth_32", "32-bit", 12, 52, 50, 26, @demo_OnDepthButton _
    ), panel
    demo_AddChild button_Create( _
        "depth_16", "16-bit", 67, 52, 50, 26, @demo_OnDepthButton _
    ), panel
    demo_AddChild button_Create( _
        "depth_8", "8-bit", 122, 52, 50, 26, @demo_OnDepthButton _
    ), panel
    demo_AddChild button_Create( _
        "depth_4", "4-bit", 177, 52, 50, 26, @demo_OnDepthButton _
    ), panel
    demo_AddChild button_Create( _
        "depth_1", "1-bit", 232, 52, 50, 26, @demo_OnDepthButton _
    ), panel

    demo_AddChild checkbox_Create( _
        "sound_checkbox", "Sound effects", 12, 94, -1 _
    ), panel
    demo_AddChild radiobox_Create( _
        "difficulty_easy", "Easy", 12, 122, 7, -1 _
    ), panel
    demo_AddChild radiobox_Create( _
        "difficulty_hard", "Hard", 88, 122, 7, 0 _
    ), panel

    demo_AddChild label_Create( _
        "alpha_label", _
        "Gallery alpha: " & DEMO_ALPHA_DEFAULT & " / " & DEMO_ALPHA_MAX, _
        12, 152 _
    ), panel
    demo_AlphaLabel = gui_FindWidget("alpha_label")
    demo_AlphaScrollbar = demo_AddChild(scrollbar_Create( _
        "alpha_scrollbar", 12, 172, 270, 18, _
        DEMO_ALPHA_MAX, 32, 0 _
    ), panel, GUI_ANCHOR_LEFT Or GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP)
    If demo_AlphaScrollbar <> 0 AndAlso _
       demo_AlphaScrollbar->data <> 0 Then
        Cast(ScrollBarData Ptr, demo_AlphaScrollbar->data)->value = _
            DEMO_ALPHA_DEFAULT
    End If

    demo_AddChild label_Create( _
        "list_label", "List box with integrated scrollbar", 12, 205 _
    ), panel
    listWidget = demo_AddChild( _
        listbox_Create("feature_list", 12, 226, 270, 174), _
        panel, _
        GUI_ANCHOR_LEFT Or GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP _
    )
    demo_FeatureList = listWidget
    listbox_AddItem listWidget, "Reactive anchors"
    listbox_AddItem listWidget, "Parent-relative controls"
    listbox_AddItem listWidget, "Modal input isolation"
    listbox_AddItem listWidget, "Open file dialog"
    listbox_AddItem listWidget, "Save file dialog"
    listbox_AddItem listWidget, "Textbox selection"
    listbox_AddItem listWidget, "Bounded undo and redo"
    listbox_AddItem listWidget, "Callback buttons"
    listbox_AddItem listWidget, "Deterministic palettes"
    listbox_AddItem listWidget, "28 imported shape kinds"
    listbox_AddItem listWidget, "Alpha and gradient fills"

    demo_AddChild button_Create( _
        "open_file", "Open...", 12, 420, 84, 28, @demo_OnOpenFile _
    ), panel
    demo_AddChild button_Create( _
        "save_file", "Save...", 105, 420, 84, 28, @demo_OnSaveFile _
    ), panel
    demo_AddChild button_Create( _
        "confirm_action", "Confirm...", 198, 420, 84, 28, @demo_OnConfirm _
    ), panel
    demo_AddChild button_Create( _
        "popup_button", "Callback menu", 12, 460, 130, 28, @demo_OnShowMenu _
    ), panel

    demo_AddChild label_Create( _
        "panel_hint", _
        "Drag, overlap, click to raise, or close with X. Wheel the list.", _
        12, 510, RGB(55, 55, 55) _
    ), panel
End Sub


Private Sub demo_BuildEditorPanel(ByVal panel As Widget Ptr)
    Dim As TextBoxData Ptr editorData
    Dim As String editorText
    Dim As Widget Ptr singleLineEditor

    editorText = _
        "omaGUI's newer editor features are live here." & Chr(10) & _
        "" & Chr(10) & _
        "Type normally, drag across text to select it, and use " & _
        "Ctrl+C, Ctrl+X, Ctrl+V, Ctrl+A, Ctrl+Z, or Ctrl+Y." & Chr(10) & _
        "" & Chr(10) & _
        "The history is bounded by entry count and stored bytes so a " & _
        "long-running editor cannot grow without limit." & Chr(10) & _
        "" & Chr(10) & _
        "Multiline feature tour:" & Chr(10) & _
        "1. Click to place the insertion cursor." & Chr(10) & _
        "2. Drag across wrapped rows to select text." & Chr(10) & _
        "3. Hold Shift while moving to extend a selection." & Chr(10) & _
        "4. Arrow keys move through logical and wrapped rows." & Chr(10) & _
        "5. Home and End move to logical line boundaries." & Chr(10) & _
        "6. Right-click to open the clipboard menu." & Chr(10) & _
        "7. The mouse wheel moves three visual rows per notch." & Chr(10) & _
        "8. The scrollbar track can be clicked or dragged." & Chr(10) & _
        "9. Wrapped rows contribute to the scroll range." & Chr(10) & _
        "10. Newline rows use the same hit-testing model." & Chr(10) & _
        "11. The cursor is kept visible after keyboard editing." & Chr(10) & _
        "12. An idle cursor does not undo wheel scrolling." & Chr(10) & _
        "13. This demo keeps the scrollbar present when disabled." & Chr(10) & _
        "14. Applications may instead select automatic visibility."

    demo_AddChild label_Create( _
        "single_label", "Single-line text with horizontal scrolling", 12, 32 _
    ), panel
    singleLineEditor = demo_AddChild( _
        textbox_Create( _
            "single_editor", _
            "Drag to select this long editable line, then copy or cut it.", _
            12, 52, 406, 26, 0, 0 _
        ), _
        panel, _
        GUI_ANCHOR_LEFT Or GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP _
    )

    demo_AddChild label_Create( _
        "editor_label", _
        "Multiline word-wrap editor: selection, clipboard, undo, redo", _
        12, 92 _
    ), panel
    demo_Editor = demo_AddChild( _
        textbox_Create( _
            "main_editor", _
            editorText, _
            12, 112, 406, 390, -1, -1, TEXTBOX_SCROLLBAR_ALWAYS _
        ), _
        panel, _
        GUI_ANCHOR_ALL _
    )
    editorData = Cast(TextBoxData Ptr, demo_Editor->data)
    If editorData <> 0 Then
        editorData->cursor_pos = 0
        editorData->sel_start = 0
        editorData->sel_end = 0
        editorData->selection_anchor = 0
        editorData->viewport_dirty = -1
    End If

    demo_AddChild button_Create( _
        "undo_button", "Undo", 12, 520, 86, 28, @demo_OnUndo _
    ), panel, GUI_ANCHOR_LEFT Or GUI_ANCHOR_BOTTOM
    demo_AddChild button_Create( _
        "redo_button", "Redo", 106, 520, 86, 28, @demo_OnRedo _
    ), panel, GUI_ANCHOR_LEFT Or GUI_ANCHOR_BOTTOM
    demo_AddChild label_Create( _
        "editor_hint", "Wheel to scroll; right-click for the context menu.", _
        206, 528, RGB(55, 55, 55) _
    ), panel, GUI_ANCHOR_RIGHT Or GUI_ANCHOR_BOTTOM
End Sub


Private Sub demo_InitGUI()
    Dim As Widget Ptr controlsPanel
    Dim As Widget Ptr editorPanel
    Dim As Widget Ptr graphicsPanel

    gui_ResetForTest()
    gui_Init()
    demo_ActiveDialog = 0
    demo_ActiveDialogKind = DEMO_DIALOG_NONE
    demo_AlphaLabel = 0
    demo_AlphaScrollbar = 0
    demo_ControlsPanel = 0
    demo_Editor = 0
    demo_EditorPanel = 0
    demo_FeatureList = 0
    demo_GraphicsPanel = 0
    demo_LastListSelection = -1
    demo_LastAlphaValue = -1
    demo_PopupMenu = 0
    demo_RequestedDepth = 0
    demo_StatusLabel = 0

    For shapeKind As Integer = GUI_SHAPE_LINE To GUI_SHAPE_EMBEDDED_SYMBOL
        demo_GalleryShapes(shapeKind) = 0
    Next shapeKind

    gui_AddWidget label_Create( _
        "demo_header", _
        "omaGUI complete feature demo", _
        10, 12, RGB(0, 45, 125) _
    )
    gui_AddWidget label_Create( _
        "demo_header_hint", _
        "Drag or overlap windows, click to raise, wheel-scroll lists, and use X to close", _
        250, 12, RGB(55, 55, 55) _
    )

    controlsPanel = subwindow_Create( _
        "controls_panel", "Interactive widgets", 10, 42, 300, 610 _
    )
    gui_AddWidget controlsPanel
    gui_SetAnchors controlsPanel, _
        GUI_ANCHOR_LEFT Or GUI_ANCHOR_TOP Or GUI_ANCHOR_BOTTOM
    demo_ControlsPanel = controlsPanel

    editorPanel = subwindow_Create( _
        "editor_panel", "Textbox editing and history", 320, 42, 430, 610 _
    )
    gui_AddWidget editorPanel
    gui_SetAnchors editorPanel, GUI_ANCHOR_ALL
    demo_EditorPanel = editorPanel

    graphicsPanel = subwindow_Create( _
        "graphics_panel", "All 28 shapes and live imported controls", _
        760, 42, 410, 610 _
    )
    gui_AddWidget graphicsPanel
    gui_SetAnchors graphicsPanel, _
        GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP Or GUI_ANCHOR_BOTTOM
    demo_GraphicsPanel = graphicsPanel

    demo_BuildControlsPanel controlsPanel
    demo_BuildEditorPanel editorPanel
    demo_AddShapeGallery graphicsPanel

    demo_StatusLabel = label_Create( _
        "status_label", _
        "Ready. Press Escape to exit.", _
        10, 675, RGB(45, 45, 45) _
    )
    gui_AddWidget demo_StatusLabel
    gui_SetAnchors demo_StatusLabel, _
        GUI_ANCHOR_LEFT Or GUI_ANCHOR_BOTTOM

    gui_AddWidget button_Create( _
        "restore_windows", "Restore windows", _
        900, 7, 110, 26, @demo_OnRestoreWindows _
    )
    gui_SetAnchors gui_FindWidget("restore_windows"), _
        GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP

    demo_PopupMenu = menu_Create("callback_popup", 0, 0)
    menu_AddItem demo_PopupMenu, "First callback", @demo_OnMenuItem
    menu_AddItem demo_PopupMenu, "Second callback", @demo_OnMenuItem
    menu_AddItem demo_PopupMenu, "Dismiss", @demo_OnMenuItem
    gui_AddWidget demo_PopupMenu
End Sub


' -------------------------------------------------------------------------
' Runtime processing
' -------------------------------------------------------------------------

Private Sub demo_ProcessDepthRequest()
    Dim As Integer requestedDepth = demo_RequestedDepth

    If requestedDepth = 0 Then Exit Sub
    demo_RequestedDepth = 0

    If backend_SetColorDepth(requestedDepth) Then
        demo_SetStatus _
            "Color mode changed to " & backend_GetColorDepth() & _
            "-bit. GUI state and resize support were preserved."
    Else
        demo_SetStatus _
            "The graphics driver rejected " & requestedDepth & _
            "-bit mode; the previous mode was restored."
    End If
End Sub


Private Sub demo_ProcessDialogResult()
    Dim As String dialogName
    Dim As Integer dialogResult
    Dim As String selectedFile

    If demo_ActiveDialog = 0 Then Exit Sub

    Select Case demo_ActiveDialogKind
    Case DEMO_DIALOG_OPEN, DEMO_DIALOG_SAVE
        dialogResult = filedialog_GetResultState(demo_ActiveDialog)
        selectedFile = filedialog_GetSelectedFile(demo_ActiveDialog)
    Case DEMO_DIALOG_CONFIRM
        dialogResult = confirmdialog_GetResultState(demo_ActiveDialog)
    End Select

    If dialogResult = 0 Then Exit Sub

    dialogName = demo_ActiveDialog->name

    If dialogResult > 0 Then
        If selectedFile <> "" Then
            demo_SetStatus "Dialog accepted: " & selectedFile
        Else
            demo_SetStatus "Confirmation accepted"
        End If
    Else
        demo_SetStatus "Dialog cancelled"
    End If

    gui_RemoveWidget dialogName
    demo_ActiveDialog = 0
    demo_ActiveDialogKind = DEMO_DIALOG_NONE
End Sub


Private Sub demo_ProcessInteractiveStatus()
    Dim As LabelData Ptr alphaLabelData
    Dim As Integer alphaValue
    Dim As Integer selectedIndex

    If demo_FeatureList <> 0 Then
        selectedIndex = listbox_GetSelectedIndex(demo_FeatureList)

        If selectedIndex <> demo_LastListSelection Then
            demo_LastListSelection = selectedIndex

            If selectedIndex >= 0 Then
                demo_SetStatus _
                    "List selected: " & _
                    listbox_GetSelectedItem(demo_FeatureList)
            End If
        End If
    End If

    If demo_AlphaScrollbar <> 0 AndAlso _
       demo_AlphaScrollbar->data <> 0 Then
        alphaValue = Cast( _
            ScrollBarData Ptr, demo_AlphaScrollbar->data _
        )->value

        If alphaValue <> demo_LastAlphaValue Then
            For shapeKind As Integer = _
                GUI_SHAPE_LINE To GUI_SHAPE_EMBEDDED_SYMBOL
                If demo_GalleryShapes(shapeKind) <> 0 Then
                    graphicshape_SetObjectAlpha _
                        demo_GalleryShapes(shapeKind), alphaValue
                End If
            Next shapeKind

            If demo_AlphaLabel <> 0 AndAlso demo_AlphaLabel->data <> 0 Then
                alphaLabelData = Cast(LabelData Ptr, demo_AlphaLabel->data)
                alphaLabelData->text = "Gallery alpha: " & alphaValue & _
                    " / " & DEMO_ALPHA_MAX
            End If

            If demo_LastAlphaValue >= 0 Then
                demo_SetStatus _
                    "Gallery alpha channel: " & alphaValue & _
                    " / " & DEMO_ALPHA_MAX
            End If

            demo_LastAlphaValue = alphaValue
        End If
    End If
End Sub


Private Sub demo_DrawHighLevelPrimitives()
    Dim As Integer screenHeight
    Dim As Integer screenWidth

    backend_GetSize screenWidth, screenHeight

    /'
        These four marks deliberately use the restored gui_Draw* convenience
        API. Their right-edge placement also makes resize behavior easy to see.
    '/
    gui_DrawLine _
        screenWidth - 150, 17, screenWidth - 122, 17, RGB(205, 30, 30)
    gui_DrawRect _
        screenWidth - 112, 10, 16, 14, RGB(20, 150, 65), 0
    gui_DrawCircle _
        screenWidth - 79, 17, 7, RGB(25, 70, 220), -1
    gui_DrawCurve _
        screenWidth - 60, 23, screenWidth - 45, 4, _
        screenWidth - 25, 17, RGB(180, 30, 180)
End Sub


backend_Init _
    DEMO_INITIAL_WIDTH, DEMO_INITIAL_HEIGHT, 0, _
    BACKEND_WINDOW_RESIZABLE, BACKEND_COLOR_DEPTH_TRUE_COLOR
WindowTitle "omaGUI complete feature demo"
demo_InitGUI

Do
    backend_Clear RGB(225, 225, 225)
    gui_UpdateAll
    demo_ProcessDepthRequest
    demo_ProcessDialogResult
    demo_ProcessInteractiveStatus
    gui_RenderAll
    demo_DrawHighLevelPrimitives
    backend_Flip

    If input_KeyPressed(KEY_ESCAPE) Then Exit Do
    Sleep 10, 1
Loop

gui_ResetForTest
backend_Exit

/' end of demo.bas '/

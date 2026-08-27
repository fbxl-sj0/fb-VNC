/'
    Project: omaGUI
    ---------------

    File: textbox_interaction_smoke.bas

    Purpose:

        Verify practical mouse, selection, clipboard, and viewport behavior
        needed by multiline source editors.

    Responsibilities:

        - place a cursor from proportional-font mouse coordinates
        - drag and render a bounded text selection
        - exercise Ctrl+C, Ctrl+X, Ctrl+V, and Ctrl+A
        - extend selection with Shift navigation
        - preserve selection through Undo
        - keep long-line cursors horizontally visible and clipped

    This file intentionally does NOT contain:

        - JRPG script compilation
        - application-specific source limits
        - interactive window automation
        - rich-text clipboard formats
'/

#define OMAGUI_IMPLEMENTATION
#lang "fb"

#include once "omaGUI.bi"

' -------------------------------------------------------------------------
' Smoke constants and cleanup
' -------------------------------------------------------------------------

Const TEXTBOX_INTERACTION_SCREEN_W As Integer = 320
Const TEXTBOX_INTERACTION_SCREEN_H As Integer = 240
Const TEXTBOX_INTERACTION_WIDGET_X As Integer = 10
Const TEXTBOX_INTERACTION_WIDGET_Y As Integer = 10
Const TEXTBOX_INTERACTION_WIDGET_W As Integer = 150
Const TEXTBOX_INTERACTION_WIDGET_H As Integer = 80
Const TEXTBOX_INTERACTION_EXIT_MOUSE As Integer = 1
Const TEXTBOX_INTERACTION_EXIT_RENDER As Integer = 2
Const TEXTBOX_INTERACTION_EXIT_CLIPBOARD As Integer = 3
Const TEXTBOX_INTERACTION_EXIT_UNDO As Integer = 4
Const TEXTBOX_INTERACTION_EXIT_KEYBOARD As Integer = 5
Const TEXTBOX_INTERACTION_EXIT_VIEWPORT As Integer = 6
Const TEXTBOX_INTERACTION_EXIT_SCREEN As Integer = 7
Const TEXTBOX_INTERACTION_SOURCE As String = _
    "alpha beta" & !"\n" & "second line" & !"\n" & "third"

' Failure cleanup is shared with the assertions below. FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared textboxInteractionSmoke_BackendActive As Integer
Dim Shared textboxInteractionSmoke_OriginalClipboard As String ' Test-owned external state. FB-LINTER: DISABLE-LINE FBL301


Sub textboxInteractionSmoke_Fail( _
    ByVal messageText As String, _
    ByVal exitCode As Integer _
)

    clipboard_SetText textboxInteractionSmoke_OriginalClipboard

    If textboxInteractionSmoke_BackendActive <> 0 Then
        backend_Exit()
        Screen 0
        textboxInteractionSmoke_BackendActive = 0
    End If

    Print "textbox interaction smoke FAILED: "; messageText
    End exitCode

End Sub


Sub textboxInteractionSmoke_Click( _
    ByVal mouseX As Integer, _
    ByVal mouseY As Integer _
)

    input_MockMouse mouseX, mouseY, 1
    gui_UpdateAll()
    input_MockMouse mouseX, mouseY, 0
    gui_UpdateAll()

End Sub


Sub textboxInteractionSmoke_Drag( _
    ByVal startX As Integer, _
    ByVal startY As Integer, _
    ByVal endX As Integer, _
    ByVal endY As Integer _
)

    input_MockMouse startX, startY, 1
    gui_UpdateAll()
    input_MockMouse endX, endY, 1
    gui_UpdateAll()
    input_MockMouse endX, endY, 0
    gui_UpdateAll()

End Sub


Sub textboxInteractionSmoke_ControlKey(ByVal keyCode As Integer)

    input_MockKey FB.SC_CONTROL, 1
    input_MockKey keyCode, 1
    gui_UpdateAll()
    input_MockKey keyCode, 0
    gui_UpdateAll()
    input_MockKey FB.SC_CONTROL, 0
    gui_UpdateAll()

End Sub

' -------------------------------------------------------------------------
' Mouse selection and platform clipboard
' -------------------------------------------------------------------------

textboxInteractionSmoke_OriginalClipboard = clipboard_GetText()
backend_Init _
    TEXTBOX_INTERACTION_SCREEN_W, TEXTBOX_INTERACTION_SCREEN_H, 1
textboxInteractionSmoke_BackendActive = 1

Dim screenWidth As Integer
Dim screenHeight As Integer

ScreenInfo screenWidth, screenHeight

If screenWidth <> TEXTBOX_INTERACTION_SCREEN_W OrElse _
   screenHeight <> TEXTBOX_INTERACTION_SCREEN_H Then
    textboxInteractionSmoke_Fail _
        "gfxlib did not create the requested surface", _
        TEXTBOX_INTERACTION_EXIT_SCREEN
End If

gui_Init()

Dim textWidget As Widget Ptr
Dim textData As TextBoxData Ptr

textWidget = textbox_Create( _
    "interaction", TEXTBOX_INTERACTION_SOURCE, _
    TEXTBOX_INTERACTION_WIDGET_X, TEXTBOX_INTERACTION_WIDGET_Y, _
    TEXTBOX_INTERACTION_WIDGET_W, TEXTBOX_INTERACTION_WIDGET_H, 1, 0 _
)

If textWidget = 0 OrElse textWidget->data = 0 Then
    textboxInteractionSmoke_Fail _
        "textbox allocation failed", TEXTBOX_INTERACTION_EXIT_SCREEN
End If

gui_AddWidget textWidget
textData = Cast(TextBoxData Ptr, textWidget->data)

Dim firstLineY As Integer
Dim selectionEndX As Integer
Dim selectionStartX As Integer

firstLineY = TEXTBOX_INTERACTION_WIDGET_Y + TEXTBOX_TEXT_LEFT_PADDING + 1
selectionStartX = TEXTBOX_INTERACTION_WIDGET_X + _
    TEXTBOX_TEXT_LEFT_PADDING + backend_GetTextWidth("alpha ")
selectionEndX = TEXTBOX_INTERACTION_WIDGET_X + _
    TEXTBOX_TEXT_LEFT_PADDING + backend_GetTextWidth("alpha beta")

textboxInteractionSmoke_Click selectionStartX, firstLineY

If textData->cursor_pos <> Len("alpha ") OrElse _
   textData->sel_start <> textData->sel_end Then
    textboxInteractionSmoke_Fail _
        "mouse click did not place the proportional-font cursor", _
        TEXTBOX_INTERACTION_EXIT_MOUSE
End If

textboxInteractionSmoke_Drag _
    selectionStartX, firstLineY, selectionEndX, firstLineY

If textData->sel_start <> Len("alpha ") OrElse _
   textData->sel_end <> Len("alpha beta") OrElse _
   textData->cursor_pos <> Len("alpha beta") Then
    textboxInteractionSmoke_Fail _
        "mouse drag did not select the expected source range", _
        TEXTBOX_INTERACTION_EXIT_MOUSE
End If

gui_RenderAll()

Dim selectionProbe As ULong
selectionProbe = Point( _
    selectionStartX + 1, _
    TEXTBOX_INTERACTION_WIDGET_Y + TEXTBOX_TEXT_LEFT_PADDING + _
        TEXTBOX_LINE_HEIGHT - 1 _
)

If selectionProbe <> current_theme.bg_select Then
    textboxInteractionSmoke_Fail _
        "selected source did not render with the theme highlight", _
        TEXTBOX_INTERACTION_EXIT_RENDER
End If

textboxInteractionSmoke_ControlKey FB.SC_C

If clipboard_GetText() <> "beta" OrElse _
   textData->text <> TEXTBOX_INTERACTION_SOURCE Then
    textboxInteractionSmoke_Fail _
        "Ctrl+C did not copy only the selected source", _
        TEXTBOX_INTERACTION_EXIT_CLIPBOARD
End If

textboxInteractionSmoke_ControlKey FB.SC_X

If textData->text <> _
   "alpha " & !"\n" & "second line" & !"\n" & "third" OrElse _
   textData->undoCount <> 1 Then
    textboxInteractionSmoke_Fail _
        "Ctrl+X did not create one reversible deletion", _
        TEXTBOX_INTERACTION_EXIT_CLIPBOARD
End If

If textbox_Undo(textWidget) = 0 OrElse _
   textData->text <> TEXTBOX_INTERACTION_SOURCE OrElse _
   textData->sel_start <> Len("alpha ") OrElse _
   textData->sel_end <> Len("alpha beta") OrElse _
   textData->selection_anchor <> Len("alpha ") Then
    textboxInteractionSmoke_Fail _
        "Undo did not restore the cut text and exact selection", _
        TEXTBOX_INTERACTION_EXIT_UNDO
End If

clipboard_SetText "BETA"
textboxInteractionSmoke_ControlKey FB.SC_V

If textData->text <> _
   "alpha BETA" & !"\n" & "second line" & !"\n" & "third" Then
    textboxInteractionSmoke_Fail _
        "Ctrl+V did not replace the selected source", _
        TEXTBOX_INTERACTION_EXIT_CLIPBOARD
End If

If textbox_Undo(textWidget) = 0 OrElse _
   textData->text <> TEXTBOX_INTERACTION_SOURCE Then
    textboxInteractionSmoke_Fail _
        "paste transaction did not restore its source", _
        TEXTBOX_INTERACTION_EXIT_UNDO
End If

' -------------------------------------------------------------------------
' Keyboard selection and horizontal viewport
' -------------------------------------------------------------------------

textboxInteractionSmoke_ControlKey FB.SC_A

If textData->sel_start <> 0 OrElse _
   textData->sel_end <> Len(TEXTBOX_INTERACTION_SOURCE) OrElse _
   textData->selection_anchor <> 0 Then
    textboxInteractionSmoke_Fail _
        "Ctrl+A did not select the complete document", _
        TEXTBOX_INTERACTION_EXIT_KEYBOARD
End If

input_MockText "replacement"
gui_UpdateAll()

If textData->text <> "replacement" OrElse textbox_Undo(textWidget) = 0 OrElse _
   textData->text <> TEXTBOX_INTERACTION_SOURCE OrElse _
   textData->sel_start <> 0 OrElse _
   textData->sel_end <> Len(TEXTBOX_INTERACTION_SOURCE) Then
    textboxInteractionSmoke_Fail _
        "typed replacement did not preserve Select All through Undo", _
        TEXTBOX_INTERACTION_EXIT_UNDO
End If

textbox_SetText textWidget, "one two" & !"\n" & "second", 1
selectionStartX = TEXTBOX_INTERACTION_WIDGET_X + _
    TEXTBOX_TEXT_LEFT_PADDING + backend_GetTextWidth("one ")
textboxInteractionSmoke_Click selectionStartX, firstLineY
input_MockKey FB.SC_LSHIFT, 1
input_MockKey KEY_END, 1
gui_UpdateAll()
input_MockKey KEY_END, 0
input_MockKey FB.SC_LSHIFT, 0
gui_UpdateAll()

If textData->sel_start <> Len("one ") OrElse _
   textData->sel_end <> Len("one two") OrElse _
   textData->cursor_pos <> Len("one two") Then
    textboxInteractionSmoke_Fail _
        "Shift+End did not extend the source selection", _
        TEXTBOX_INTERACTION_EXIT_KEYBOARD
End If

Dim secondLineX As Integer
Dim secondLineY As Integer

secondLineX = TEXTBOX_INTERACTION_WIDGET_X + _
    TEXTBOX_TEXT_LEFT_PADDING + backend_GetTextWidth("sec")
secondLineY = firstLineY + TEXTBOX_LINE_HEIGHT
textboxInteractionSmoke_Click secondLineX, secondLineY

If textData->cursor_pos <> Len("one two" & !"\n" & "sec") Then
    textboxInteractionSmoke_Fail _
        "second-line mouse click did not resolve its logical position", _
        TEXTBOX_INTERACTION_EXIT_MOUSE
End If

textbox_SetText textWidget, "012345678901234567890123456789", 1
gui_UpdateAll()

If textData->scroll_offset <= 0 Then
    textboxInteractionSmoke_Fail _
        "long-line cursor did not advance the horizontal viewport", _
        TEXTBOX_INTERACTION_EXIT_VIEWPORT
End If

textboxInteractionSmoke_Click _
    TEXTBOX_INTERACTION_WIDGET_X + TEXTBOX_TEXT_LEFT_PADDING, firstLineY

If textData->cursor_pos <= 0 OrElse _
   textData->cursor_pos >= Len(textData->text) Then
    textboxInteractionSmoke_Fail _
        "mouse placement ignored the horizontal viewport", _
        TEXTBOX_INTERACTION_EXIT_VIEWPORT
End If

input_MockKey KEY_HOME, 1
gui_UpdateAll()
input_MockKey KEY_HOME, 0
gui_UpdateAll()

If textData->cursor_pos <> 0 OrElse textData->scroll_offset <> 0 Then
    textboxInteractionSmoke_Fail _
        "Home did not return the cursor and viewport to line start", _
        TEXTBOX_INTERACTION_EXIT_VIEWPORT
End If

clipboard_SetText textboxInteractionSmoke_OriginalClipboard
backend_Exit()
Screen 0
textboxInteractionSmoke_BackendActive = 0

Print "textbox interaction smoke OK: mouse, selection, clipboard, viewport"

' end of textbox_interaction_smoke.bas

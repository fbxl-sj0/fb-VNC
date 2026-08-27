/'
    Project: omaGUI
    ---------------

    File: textbox_editing_smoke.bas

    Purpose:

        Verify editing behavior required by multiline tool surfaces such as
        the JRPG map editor's object-script popup.

    Responsibilities:

        - insert and delete text at an internal cursor position
        - replace a selected span through ordinary text input
        - navigate multiline text with cursor, home, end, up, and down keys
        - keep an off-screen active cursor visible through vertical scrolling

    This file intentionally does NOT contain:

        - platform event-loop integration
        - graphics screenshot assertions
        - application-specific script compilation
'/

#define OMAGUI_IMPLEMENTATION
#lang "fb"

#include once "omaGUI.bi"

Const TEXTBOX_EDITING_SMOKE_EXIT_INSERT As Integer = 1
Const TEXTBOX_EDITING_SMOKE_EXIT_BACKSPACE As Integer = 2
Const TEXTBOX_EDITING_SMOKE_EXIT_DELETE As Integer = 3
Const TEXTBOX_EDITING_SMOKE_EXIT_SELECTION As Integer = 4
Const TEXTBOX_EDITING_SMOKE_EXIT_HOME_END As Integer = 5
Const TEXTBOX_EDITING_SMOKE_EXIT_VERTICAL As Integer = 6
Const TEXTBOX_EDITING_SMOKE_EXIT_RETURN As Integer = 7
Const TEXTBOX_EDITING_SMOKE_EXIT_SCROLL As Integer = 8
Const TEXTBOX_EDITING_SMOKE_LINE_BREAK As String = Chr(10)
Const TEXTBOX_EDITING_SMOKE_LONG_LINE_COUNT As Integer = 32

Dim textWidget As Widget Ptr
Dim textData As TextBoxData Ptr
Dim longText As String
Dim longLineText As String
Dim longTextLength As Integer
Dim longTextOffset As Integer

backend_Init 320, 240
gui_Init()

textWidget = textbox_Create("editing", "alpha", 10, 10, 200, 120, 1, 0)
gui_AddWidget textWidget
textData = Cast(TextBoxData Ptr, textWidget->data)

input_MockMouse 20, 20, 1
gui_UpdateAll()
input_MockMouse 20, 20, 0
gui_UpdateAll()

textData->cursor_pos = 2
textData->sel_start = 2
textData->sel_end = 2
input_MockText "X"
gui_UpdateAll()

If textData->text <> "alXpha" OrElse textData->cursor_pos <> 3 Then
    Print "textbox editing smoke failed: insert did not use the cursor"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_INSERT
End If

input_MockKey KEY_BACKSPACE, 1
gui_UpdateAll()
input_MockKey KEY_BACKSPACE, 0
gui_UpdateAll()

If textData->text <> "alpha" OrElse textData->cursor_pos <> 2 Then
    Print "textbox editing smoke failed: backspace did not use the cursor"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_BACKSPACE
End If

input_MockKey KEY_DELETE, 1
gui_UpdateAll()
input_MockKey KEY_DELETE, 0
gui_UpdateAll()

If textData->text <> "alha" OrElse textData->cursor_pos <> 2 Then
    Print "textbox editing smoke failed: delete did not use the cursor"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_DELETE
End If

textData->text = "alpha"
textData->cursor_pos = 4
textData->sel_start = 1
textData->sel_end = 4
input_MockText "X"
gui_UpdateAll()

If textData->text <> "aXa" OrElse textData->cursor_pos <> 2 OrElse _
   textData->sel_start <> 2 OrElse textData->sel_end <> 2 Then
    Print "textbox editing smoke failed: selection replacement was wrong"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_SELECTION
End If

textData->text = "one" & TEXTBOX_EDITING_SMOKE_LINE_BREAK & "three"
textData->cursor_pos = 6
textData->sel_start = 6
textData->sel_end = 6
input_MockKey KEY_UP, 1
gui_UpdateAll()
input_MockKey KEY_UP, 0
gui_UpdateAll()

If textData->cursor_pos <> 2 Then
    Print "textbox editing smoke failed: up navigation was wrong"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_VERTICAL
End If

input_MockKey KEY_DOWN, 1
gui_UpdateAll()
input_MockKey KEY_DOWN, 0
gui_UpdateAll()

If textData->cursor_pos <> 6 Then
    Print "textbox editing smoke failed: down navigation was wrong"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_VERTICAL
End If

input_MockKey KEY_HOME, 1
gui_UpdateAll()
input_MockKey KEY_HOME, 0
gui_UpdateAll()

If textData->cursor_pos <> 4 Then
    Print "textbox editing smoke failed: home navigation was wrong"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_HOME_END
End If

input_MockKey KEY_END, 1
gui_UpdateAll()
input_MockKey KEY_END, 0
gui_UpdateAll()

If textData->cursor_pos <> Len(textData->text) Then
    Print "textbox editing smoke failed: end navigation was wrong"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_HOME_END
End If

textData->text = "ab"
textData->cursor_pos = 1
textData->sel_start = 1
textData->sel_end = 1
input_MockKey KEY_RETURN, 1
gui_UpdateAll()
input_MockKey KEY_RETURN, 0
gui_UpdateAll()

If textData->text <> "a" & TEXTBOX_EDITING_SMOKE_LINE_BREAK & "b" OrElse _
   textData->cursor_pos <> 2 Then
    Print "textbox editing smoke failed: multiline return was wrong"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_RETURN
End If

For i As Integer = 1 To TEXTBOX_EDITING_SMOKE_LONG_LINE_COUNT
    longLineText = "line " & LTrim(Str(i)) & _
        TEXTBOX_EDITING_SMOKE_LINE_BREAK
    longTextLength += Len(longLineText)
Next i

longText = Space(longTextLength)
longTextOffset = 1

For i As Integer = 1 To TEXTBOX_EDITING_SMOKE_LONG_LINE_COUNT
    longLineText = "line " & LTrim(Str(i)) & _
        TEXTBOX_EDITING_SMOKE_LINE_BREAK
    Mid(longText, longTextOffset, Len(longLineText)) = longLineText
    longTextOffset += Len(longLineText)
Next i

textData->text = longText
textData->cursor_pos = Len(textData->text)
textData->sel_start = textData->cursor_pos
textData->sel_end = textData->cursor_pos
gui_UpdateAll()

If textData->v_scroll <= 0 Then
    Print "textbox editing smoke failed: cursor did not scroll into view"
    backend_Exit()
    End TEXTBOX_EDITING_SMOKE_EXIT_SCROLL
End If

backend_Exit()
Print "textbox editing smoke OK"
End 0

' end of textbox_editing_smoke.bas

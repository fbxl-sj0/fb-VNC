/'
    Project: omaGUI
    ---------------

    File: textbox_history_smoke.bas

    Purpose:

        Verify bounded per-widget text Undo and Redo through the shared input
        path used by JRPG source editors.

    Responsibilities:

        - coalesce ordinary typing into one reversible transaction
        - preserve cursor and selection state
        - latch held Ctrl+Z and Ctrl+Y keys
        - clear stale Redo after divergent input
        - reset history when a textbox begins another document
        - enforce entry-count and aggregate-byte bounds

    This file intentionally does NOT contain:

        - JRPG script compilation
        - platform clipboard dependencies
        - map Undo or Redo state
        - interactive window automation
'/

#define OMAGUI_IMPLEMENTATION
#lang "fb"

#include once "omaGUI.bi"

' -------------------------------------------------------------------------
' Smoke constants and lifecycle
' -------------------------------------------------------------------------

Const TEXTBOX_HISTORY_SMOKE_SCREEN_W As Integer = 320
Const TEXTBOX_HISTORY_SMOKE_SCREEN_H As Integer = 240
Const TEXTBOX_HISTORY_SMOKE_WIDGET_X As Integer = 10
Const TEXTBOX_HISTORY_SMOKE_WIDGET_Y As Integer = 10
Const TEXTBOX_HISTORY_SMOKE_WIDGET_W As Integer = 240
Const TEXTBOX_HISTORY_SMOKE_WIDGET_H As Integer = 120
' The focus click is deliberately past the short initial line so it selects EOF.
Const TEXTBOX_HISTORY_SMOKE_MOUSE_X As Integer = 100
Const TEXTBOX_HISTORY_SMOKE_MOUSE_Y As Integer = 20
Const TEXTBOX_HISTORY_SMOKE_EXIT_SCREEN As Integer = 1
Const TEXTBOX_HISTORY_SMOKE_EXIT_TYPING As Integer = 2
Const TEXTBOX_HISTORY_SMOKE_EXIT_CURSOR As Integer = 3
Const TEXTBOX_HISTORY_SMOKE_EXIT_LATCH As Integer = 4
Const TEXTBOX_HISTORY_SMOKE_EXIT_DIVERGENT As Integer = 5
Const TEXTBOX_HISTORY_SMOKE_EXIT_RESET As Integer = 6
Const TEXTBOX_HISTORY_SMOKE_EXIT_BOUND As Integer = 7

' Failure cleanup is shared with the assertions below. FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared textboxHistorySmoke_BackendActive As Integer


Sub textboxHistorySmoke_Fail( _
    ByVal messageText As String, _
    ByVal exitCode As Integer _
)

    If textboxHistorySmoke_BackendActive <> 0 Then
        backend_Exit()
        Screen 0
        textboxHistorySmoke_BackendActive = 0
    End If

    Print "textbox history smoke FAILED: "; messageText
    End exitCode

End Sub


Sub textboxHistorySmoke_ReleaseKey(ByVal keyCode As Integer)

    input_MockKey keyCode, 0
    gui_UpdateAll()

End Sub

' -------------------------------------------------------------------------
' Typing, exact restoration, and shortcut latching
' -------------------------------------------------------------------------

backend_Init _
    TEXTBOX_HISTORY_SMOKE_SCREEN_W, TEXTBOX_HISTORY_SMOKE_SCREEN_H, 1
textboxHistorySmoke_BackendActive = 1

Dim screenWidth As Integer
Dim screenHeight As Integer

ScreenInfo screenWidth, screenHeight

If screenWidth <> TEXTBOX_HISTORY_SMOKE_SCREEN_W OrElse _
   screenHeight <> TEXTBOX_HISTORY_SMOKE_SCREEN_H Then
    textboxHistorySmoke_Fail _
        "gfxlib did not create the requested surface", _
        TEXTBOX_HISTORY_SMOKE_EXIT_SCREEN
End If

gui_Init()

Dim textWidget As Widget Ptr
Dim textData As TextBoxData Ptr

textWidget = textbox_Create( _
    "history", "start", TEXTBOX_HISTORY_SMOKE_WIDGET_X, _
    TEXTBOX_HISTORY_SMOKE_WIDGET_Y, TEXTBOX_HISTORY_SMOKE_WIDGET_W, _
    TEXTBOX_HISTORY_SMOKE_WIDGET_H, 1, 0 _
)

If textWidget = 0 OrElse textWidget->data = 0 Then
    textboxHistorySmoke_Fail _
        "textbox allocation failed", TEXTBOX_HISTORY_SMOKE_EXIT_SCREEN
End If

gui_AddWidget textWidget
textData = Cast(TextBoxData Ptr, textWidget->data)
input_MockMouse _
    TEXTBOX_HISTORY_SMOKE_MOUSE_X, TEXTBOX_HISTORY_SMOKE_MOUSE_Y, 1
gui_UpdateAll()
input_MockMouse _
    TEXTBOX_HISTORY_SMOKE_MOUSE_X, TEXTBOX_HISTORY_SMOKE_MOUSE_Y, 0
gui_UpdateAll()

input_MockText "a"
gui_UpdateAll()
input_MockText "b"
gui_UpdateAll()
input_MockText "c"
gui_UpdateAll()

If textData->text <> "startabc" OrElse textData->undoCount <> 1 Then
    textboxHistorySmoke_Fail _
        "typing did not coalesce into one transaction", _
        TEXTBOX_HISTORY_SMOKE_EXIT_TYPING
End If

input_MockKey FB.SC_CONTROL, 1
input_MockKey FB.SC_Z, 1
gui_UpdateAll()

If textData->text <> "start" OrElse textData->cursor_pos <> Len("start") OrElse _
   textData->sel_start <> Len("start") OrElse _
   textData->sel_end <> Len("start") Then
    textboxHistorySmoke_Fail _
        "Ctrl+Z did not restore text, cursor, and selection", _
        TEXTBOX_HISTORY_SMOKE_EXIT_CURSOR
End If

' A held key must not consume another entry.
gui_UpdateAll()

If textData->text <> "start" OrElse textData->redoCount <> 1 Then
    textboxHistorySmoke_Fail _
        "held Ctrl+Z bypassed the shortcut latch", _
        TEXTBOX_HISTORY_SMOKE_EXIT_LATCH
End If

textboxHistorySmoke_ReleaseKey FB.SC_Z
input_MockKey FB.SC_Y, 1
gui_UpdateAll()

If textData->text <> "startabc" OrElse _
   textData->cursor_pos <> Len("startabc") Then
    textboxHistorySmoke_Fail _
        "Ctrl+Y did not restore the coalesced result", _
        TEXTBOX_HISTORY_SMOKE_EXIT_CURSOR
End If

gui_UpdateAll()

If textData->text <> "startabc" Then
    textboxHistorySmoke_Fail _
        "held Ctrl+Y bypassed the shortcut latch", _
        TEXTBOX_HISTORY_SMOKE_EXIT_LATCH
End If

textboxHistorySmoke_ReleaseKey FB.SC_Y
input_MockKey FB.SC_CONTROL, 0
gui_UpdateAll()

' -------------------------------------------------------------------------
' Divergence, document reset, and storage bounds
' -------------------------------------------------------------------------

If textbox_Undo(textWidget) = 0 Then
    textboxHistorySmoke_Fail _
        "direct Undo could not reach the typing baseline", _
        TEXTBOX_HISTORY_SMOKE_EXIT_DIVERGENT
End If

input_MockText "different"
gui_UpdateAll()

If textData->text <> "startdifferent" OrElse textData->redoCount <> 0 Then
    textboxHistorySmoke_Fail _
        "divergent typing retained stale Redo", _
        TEXTBOX_HISTORY_SMOKE_EXIT_DIVERGENT
End If

If textbox_SetText(textWidget, "new document", 1) = 0 OrElse _
   textData->undoCount <> 0 OrElse textData->redoCount <> 0 OrElse _
   textbox_Undo(textWidget) <> 0 Then
    textboxHistorySmoke_Fail _
        "new-document reset retained prior source history", _
        TEXTBOX_HISTORY_SMOKE_EXIT_RESET
End If

For editIndex As Integer = 1 To TEXTBOX_HISTORY_MAX_ENTRIES + 4
    If textbox_SetText( _
        textWidget, "revision " & LTrim(Str(editIndex)), 0 _
    ) = 0 Then
        textboxHistorySmoke_Fail _
            "programmatic edit transaction failed", _
            TEXTBOX_HISTORY_SMOKE_EXIT_BOUND
    End If
Next editIndex

If textData->undoCount <> TEXTBOX_HISTORY_MAX_ENTRIES OrElse _
   textData->historyStoredBytes < 0 OrElse _
   textData->historyStoredBytes > TEXTBOX_HISTORY_MAX_STORED_BYTES Then
    textboxHistorySmoke_Fail _
        "history escaped its entry or aggregate-byte bound", _
        TEXTBOX_HISTORY_SMOKE_EXIT_BOUND
End If

backend_Exit()
Screen 0
textboxHistorySmoke_BackendActive = 0

Print "textbox history smoke OK: entries "; TEXTBOX_HISTORY_MAX_ENTRIES

' end of textbox_history_smoke.bas

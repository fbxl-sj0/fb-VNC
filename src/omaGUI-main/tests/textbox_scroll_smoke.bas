/'
    Project: omaGUI Test Suite
    --------------------------

    File: textbox_scroll_smoke.bas

    Purpose:

        Verify multiline textbox scrollbar policies and visual-row scrolling.

    Responsibilities:

        - prove the always-present policy disables an unnecessary scrollbar
        - prove the automatic policy appears and disappears with overflow
        - prove newline and word-wrapped content share one scroll range
        - prove wheel scrolling remains in place while the cursor is idle
        - prove the integrated scrollbar can change the multiline viewport

    This file intentionally does NOT contain:

        - native mouse-wheel polling
        - screenshot comparison
        - application-specific editor behavior
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Const TEXTBOX_SCROLL_SMOKE_WIDTH As Integer = 640
Const TEXTBOX_SCROLL_SMOKE_HEIGHT As Integer = 260

Private Sub textboxScrollSmoke_Fail( _
    ByVal messageText As String, ByVal exitCode As Integer _
)
    gui_ResetForTest
    backend_Exit
    Print "textbox scroll smoke failed: " & messageText
    End exitCode
End Sub


Private Sub textboxScrollSmoke_Click(ByVal x As Integer, ByVal y As Integer)
    input_MockMouse x, y, 1
    gui_UpdateAll
    input_MockMouse x, y, 0
    gui_UpdateAll
End Sub


Dim As Widget Ptr alwaysEditor
Dim As TextBoxData Ptr alwaysData
Dim As ScrollBarData Ptr alwaysScrollData
Dim As Widget Ptr autoEditor
Dim As TextBoxData Ptr autoData
Dim As ScrollBarData Ptr autoScrollData
Dim As String longText
Dim As Widget Ptr wrapEditor
Dim As TextBoxData Ptr wrapData

backend_Init TEXTBOX_SCROLL_SMOKE_WIDTH, TEXTBOX_SCROLL_SMOKE_HEIGHT, -1
gui_Init
input_ResetForTest

alwaysEditor = textbox_Create( _
    "always_editor", "Short text", 10, 10, 180, 90, -1, -1, _
    TEXTBOX_SCROLLBAR_ALWAYS _
)
autoEditor = textbox_Create( _
    "auto_editor", "Short text", 210, 10, 180, 90, -1, -1 _
)
wrapEditor = textbox_Create( _
    "wrap_editor", _
    "A deliberately long logical line with enough words to wrap across " & _
    "many visual rows in this narrow multiline editor. This same line " & _
    "continues with additional words so it cannot fit in one viewport. " & _
    "Wrapped rows must count as scrollable content even without a newline.", _
    410, 10, 180, 90, -1, -1, TEXTBOX_SCROLLBAR_AUTO _
)

If alwaysEditor = 0 OrElse autoEditor = 0 OrElse wrapEditor = 0 Then
    textboxScrollSmoke_Fail "widget allocation failed", 1
End If

gui_AddWidget alwaysEditor
gui_AddWidget autoEditor
gui_AddWidget wrapEditor
gui_UpdateAll

alwaysData = Cast(TextBoxData Ptr, alwaysEditor->data)
autoData = Cast(TextBoxData Ptr, autoEditor->data)
wrapData = Cast(TextBoxData Ptr, wrapEditor->data)

If alwaysData = 0 OrElse alwaysData->vertical_scrollbar = 0 OrElse _
   alwaysData->vertical_scrollbar->data = 0 Then
    textboxScrollSmoke_Fail "always policy did not own a scrollbar", 2
End If

alwaysScrollData = Cast( _
    ScrollBarData Ptr, alwaysData->vertical_scrollbar->data _
)
If alwaysData->scrollbar_visible = 0 OrElse _
   alwaysScrollData->max_val <> 0 OrElse _
   alwaysData->vertical_scrollbar->enabled <> 0 Then
    textboxScrollSmoke_Fail _
        "always policy did not show a disabled short-content scrollbar", 3
End If

If autoData->scrollbar_visible <> 0 Then
    textboxScrollSmoke_Fail _
        "automatic policy showed a scrollbar for short content", 4
End If

If wrapData->scrollbar_visible = 0 OrElse _
   wrapData->total_visual_lines <= 1 Then
    textboxScrollSmoke_Fail _
        "word-wrapped visual rows did not create automatic overflow", 5
End If

longText = _
    "Line 0" & Chr(10) & "Line 1" & Chr(10) & _
    "Line 2" & Chr(10) & "Line 3" & Chr(10) & _
    "Line 4" & Chr(10) & "Line 5" & Chr(10) & _
    "Line 6" & Chr(10) & "Line 7" & Chr(10) & _
    "Line 8" & Chr(10) & "Line 9" & Chr(10) & _
    "Line 10" & Chr(10) & "Line 11" & Chr(10) & _
    "Line 12" & Chr(10) & "Line 13" & Chr(10) & _
    "Line 14" & Chr(10) & "Line 15" & Chr(10) & _
    "Line 16" & Chr(10) & "Line 17" & Chr(10) & _
    "Line 18" & Chr(10) & "Line 19" & Chr(10) & "Line 20"

textbox_SetText autoEditor, longText, -1
gui_UpdateAll
autoScrollData = Cast( _
    ScrollBarData Ptr, autoData->vertical_scrollbar->data _
)

If autoData->scrollbar_visible = 0 OrElse _
   autoScrollData->max_val <= 0 OrElse _
   autoData->vertical_scrollbar->enabled = 0 Then
    textboxScrollSmoke_Fail _
        "automatic policy did not enable for multiline overflow", 6
End If

autoData->v_scroll = 0
textboxScrollSmoke_Click autoEditor->ax + 8, autoEditor->ay + 8
input_MockMouse autoEditor->ax + 8, autoEditor->ay + 8, 0, -1
gui_UpdateAll

If autoData->v_scroll <= 0 Then
    textboxScrollSmoke_Fail "mouse wheel did not scroll multiline text", 7
End If

Dim As Integer wheelPosition = autoData->v_scroll
input_MockMouse autoEditor->ax + 8, autoEditor->ay + 8, 0, 0
gui_UpdateAll

If autoData->v_scroll <> wheelPosition Then
    textboxScrollSmoke_Fail _
        "idle cursor pulled the wheel-scrolled viewport back", 8
End If

textboxScrollSmoke_Click _
    autoData->vertical_scrollbar->ax + _
        autoData->vertical_scrollbar->w \ 2, _
    autoData->vertical_scrollbar->ay + _
        autoData->vertical_scrollbar->h - 2

If autoData->v_scroll <= wheelPosition Then
    textboxScrollSmoke_Fail _
        "integrated scrollbar did not move the viewport", 9
End If

textbox_SetText autoEditor, "Short again", -1
gui_UpdateAll
If autoData->scrollbar_visible <> 0 OrElse autoData->v_scroll <> 0 Then
    textboxScrollSmoke_Fail _
        "automatic scrollbar did not disappear after content shrank", 10
End If

textbox_SetVerticalScrollbar autoEditor, TEXTBOX_SCROLLBAR_ALWAYS
If textbox_GetVerticalScrollbarMode(autoEditor) <> _
   TEXTBOX_SCROLLBAR_ALWAYS OrElse autoData->scrollbar_visible = 0 Then
    textboxScrollSmoke_Fail "runtime policy setter did not take effect", 11
End If

textbox_SetVerticalScrollbar autoEditor, TEXTBOX_SCROLLBAR_NONE
If textbox_GetVerticalScrollbarMode(autoEditor) <> _
   TEXTBOX_SCROLLBAR_NONE OrElse autoData->scrollbar_visible <> 0 Then
    textboxScrollSmoke_Fail "none policy did not hide the scrollbar", 12
End If

gui_ResetForTest
backend_Exit
Print "textbox scroll smoke OK"
End 0

/' end of textbox_scroll_smoke.bas '/

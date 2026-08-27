/'
    Project: omaGUI
    ---------------

    File: parent_modal_smoke.bas

    Purpose:
        Smoke-test parent-relative widget layout, callback buttons, and modal
        interaction boundaries.

    Responsibilities:
        - click a child button through a subwindow offset
        - confirm modal state blocks unrelated controls
        - confirm removing a parent also removes its registered children

    This file intentionally does NOT contain:
        - application-specific editor behavior
        - filesystem dialog tests
        - renderer snapshot comparisons
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGui.bi"

Const PARENT_MODAL_SMOKE_WIDTH As Integer = 320
Const PARENT_MODAL_SMOKE_HEIGHT As Integer = 200
Const PARENT_MODAL_WINDOW_X As Integer = 100
Const PARENT_MODAL_WINDOW_Y As Integer = 60
Const PARENT_MODAL_BUTTON_X As Integer = 12
Const PARENT_MODAL_BUTTON_Y As Integer = 28
Const PARENT_MODAL_BUTTON_W As Integer = 64
Const PARENT_MODAL_BUTTON_H As Integer = 24

' Shared state boundary: these counters are owned by the modal test callbacks below.
Dim Shared insideClicks As Integer
Dim Shared outsideClicks As Integer

Sub parent_modal_OnInside(ByVal w As Widget Ptr)
    insideClicks += 1
End Sub

Sub parent_modal_OnOutside(ByVal w As Widget Ptr)
    outsideClicks += 1
End Sub

backend_Init PARENT_MODAL_SMOKE_WIDTH, PARENT_MODAL_SMOKE_HEIGHT, 1
gui_Init()

Dim As Widget Ptr windowWidget
Dim As Widget Ptr insideButton
Dim As Widget Ptr outsideButton

windowWidget = subwindow_Create( _
    "parent_modal_window", _
    "Window", _
    PARENT_MODAL_WINDOW_X, _
    PARENT_MODAL_WINDOW_Y, _
    160, _
    100 _
)
insideButton = button_Create( _
    "parent_modal_inside", _
    "Inside", _
    PARENT_MODAL_BUTTON_X, _
    PARENT_MODAL_BUTTON_Y, _
    PARENT_MODAL_BUTTON_W, _
    PARENT_MODAL_BUTTON_H, _
    @parent_modal_OnInside _
)
outsideButton = button_Create("parent_modal_outside", "Outside", 8, 8, 64, 24, @parent_modal_OnOutside)

gui_AddWidget windowWidget
gui_AddWidget insideButton
gui_AddWidget outsideButton
gui_SetParent insideButton, windowWidget
gui_SetModalRoot windowWidget

input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 1
gui_UpdateAll()
input_MockMouse PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X + 1, PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y + 1, 0
gui_UpdateAll()

If insideClicks <> 1 Then
    Print "parent modal smoke failed: child callback did not run"
    End 1
End If

If insideButton->ax <> PARENT_MODAL_WINDOW_X + PARENT_MODAL_BUTTON_X OrElse _
   insideButton->ay <> PARENT_MODAL_WINDOW_Y + PARENT_MODAL_BUTTON_Y Then
    Print "parent modal smoke failed: child absolute position was wrong"
    End 2
End If

input_MockMouse 9, 9, 1
gui_UpdateAll()
input_MockMouse 9, 9, 0
gui_UpdateAll()

If outsideClicks <> 0 Then
    Print "parent modal smoke failed: modal root allowed outside callback"
    End 3
End If

gui_RemoveWidget "parent_modal_window"

If gui_FindWidget("parent_modal_window") <> 0 OrElse _
   gui_FindWidget("parent_modal_inside") <> 0 Then
    Print "parent modal smoke failed: parent removal left child registered"
    End 4
End If

gui_RemoveWidget "parent_modal_outside"
backend_Exit()

Print "parent modal smoke OK"
End 0

' end of parent_modal_smoke.bas

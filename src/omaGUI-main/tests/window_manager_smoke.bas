/'
    Project: omaGUI Test Suite
    --------------------------

    File: window_manager_smoke.bas

    Purpose:

        Verify ordered subwindows, routed input, client clipping, closing, and
        wheel-driven list interaction.

    Responsibilities:

        - prove only the foreground overlapping control receives a click
        - prove clicking an exposed title raises its complete window tree
        - prove children cannot draw or receive input outside the client area
        - prove close and reopen update the complete child tree
        - prove list selection, keyboard focus, and wheel scrolling work

    This file intentionally does NOT contain:

        - native operating-system window resizing
        - screenshot comparison
        - application-specific dialog behavior
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Const WINDOW_MANAGER_WIDTH As Integer = 400
Const WINDOW_MANAGER_HEIGHT As Integer = 300

/'
    Callback-owned test state

    The two button callbacks increment these counters so the test can prove
    that one pointer release reaches only the foreground window tree.
'/
Dim Shared As Integer backButtonClicks
Dim Shared As Integer frontButtonClicks
Dim Shared As Integer clippedButtonClicks

Private Sub windowManager_OnBackButton(ByVal w As Widget Ptr)
    backButtonClicks += 1
End Sub


Private Sub windowManager_OnFrontButton(ByVal w As Widget Ptr)
    frontButtonClicks += 1
End Sub


Private Sub windowManager_OnClippedButton(ByVal w As Widget Ptr)
    clippedButtonClicks += 1
End Sub


Private Sub windowManager_Click(ByVal x As Integer, ByVal y As Integer)
    input_MockMouse x, y, 1
    gui_UpdateAll
    input_MockMouse x, y, 0
    gui_UpdateAll
End Sub


Private Sub windowManager_Fail( _
    ByVal messageText As String, ByVal exitCode As Integer _
)
    gui_ResetForTest
    backend_Exit
    Print "window manager smoke failed: " & messageText
    End exitCode
End Sub


Dim As Widget Ptr backWindow
Dim As Widget Ptr backButton
Dim As Widget Ptr clippedButton
Dim As Widget Ptr frontWindow
Dim As Widget Ptr frontButton
Dim As Widget Ptr itemList
Dim As ULong backgroundColor = RGB(10, 20, 30)

backend_Init WINDOW_MANAGER_WIDTH, WINDOW_MANAGER_HEIGHT, -1
gui_Init
input_ResetForTest

backWindow = subwindow_Create( _
    "window_back", "Back", 50, 50, 180, 160 _
)
backButton = button_Create( _
    "window_back_button", "Back", 70, 70, 80, 28, _
    @windowManager_OnBackButton _
)
clippedButton = button_Create( _
    "window_clipped_button", "Clipped", -30, 110, 80, 28, _
    @windowManager_OnClippedButton _
)

frontWindow = subwindow_Create( _
    "window_front", "Front", 90, 70, 180, 160 _
)
frontButton = button_Create( _
    "window_front_button", "Front", 30, 50, 80, 28, _
    @windowManager_OnFrontButton _
)
itemList = listbox_Create( _
    "window_item_list", 10, 90, 150, 64 _
)

If backWindow = 0 OrElse backButton = 0 OrElse _
   clippedButton = 0 OrElse frontWindow = 0 OrElse _
   frontButton = 0 OrElse itemList = 0 Then
    windowManager_Fail "widget allocation failed", 1
End If

gui_AddWidget backWindow
gui_AddWidget backButton
gui_AddWidget clippedButton
gui_SetParent backButton, backWindow
gui_SetParent clippedButton, backWindow

gui_AddWidget frontWindow
gui_AddWidget frontButton
gui_AddWidget itemList
gui_SetParent frontButton, frontWindow
gui_SetParent itemList, frontWindow

For itemIndex As Integer = 0 To 15
    listbox_AddItem itemList, "Item " & itemIndex
Next itemIndex

windowManager_Click 130, 130
If frontButtonClicks <> 1 OrElse backButtonClicks <> 0 Then
    windowManager_Fail "background window received foreground click", 2
End If

windowManager_Click 60, 60
windowManager_Click 130, 130
If backButtonClicks <> 1 OrElse frontButtonClicks <> 1 Then
    windowManager_Fail "title activation did not raise complete window tree", 3
End If

windowManager_Click 30, 175
If clippedButtonClicks <> 0 Then
    windowManager_Fail "child received input outside parent client", 4
End If

backend_Clear backgroundColor
gui_RenderAll
If Point(30, 175) <> backgroundColor Then
    windowManager_Fail "child rendered outside parent client", 5
End If

windowManager_Click 240, 75
input_MockMouse 120, 175, 0, -1
gui_UpdateAll

If Cast(ListBoxData Ptr, itemList->data)->scroll_top <= 0 Then
    windowManager_Fail "mouse wheel did not scroll list", 6
End If

windowManager_Click 120, 175
If listbox_GetSelectedIndex(itemList) < 0 OrElse _
   listbox_GetSelectedItem(itemList) = "" Then
    windowManager_Fail "list pointer selection did not update", 7
End If

Dim As Integer selectedBeforeKey = listbox_GetSelectedIndex(itemList)
input_MockKey KEY_DOWN, -1
gui_UpdateAll
input_MockKey KEY_DOWN, 0
gui_UpdateAll

If listbox_GetSelectedIndex(itemList) <= selectedBeforeKey Then
    windowManager_Fail "focused list ignored keyboard navigation", 8
End If

windowManager_Click 259, 80
If frontWindow->visible <> 0 OrElse itemList->evis <> 0 OrElse _
   subwindow_CloseRequested(frontWindow) = 0 Then
    windowManager_Fail "close control did not hide complete window tree", 9
End If

subwindow_Reopen frontWindow
gui_UpdateAll
If frontWindow->visible = 0 OrElse itemList->evis = 0 Then
    windowManager_Fail "reopen did not restore complete window tree", 10
End If

gui_ResetForTest
backend_Exit
Print "window manager smoke OK"
End 0

/' end of window_manager_smoke.bas '/

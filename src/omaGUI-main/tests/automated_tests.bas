/'
    Project: omaGUI
    ---------------

    File: automated_tests.bas

    Purpose:

        Verify the master include and basic widget registry lifecycle.

    Responsibilities:

        - initialize omaGUI through its public single-include entry point
        - add, find, and remove one ordinary widget
        - preserve unambiguous lookup names when a duplicate is registered

    This file intentionally does NOT contain:

        - detailed interaction tests
        - renderer comparisons
        - application-specific GUI behavior
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

backend_Init 800, 600, 1
gui_Init()

Dim As Widget Ptr buttonWidget = button_Create( _
    "test_btn", "OK", 50, 50, 60, 30 _
)
Dim As Widget Ptr duplicateButton = button_Create( _
    "test_btn", "Duplicate", 120, 50, 80, 30 _
)
gui_AddWidget buttonWidget
gui_AddWidget duplicateButton

If buttonWidget = 0 OrElse gui_FindWidget("test_btn") <> buttonWidget Then
    backend_Exit()
    End 1
End If

If duplicateButton = 0 OrElse duplicateButton->name <> "test_btn_1" OrElse _
   gui_FindWidget("test_btn_1") <> duplicateButton Then
    backend_Exit()
    End 2
End If

gui_RemoveWidget "test_btn"
gui_RemoveWidget "test_btn_1"

If gui_FindWidget("test_btn") <> 0 OrElse _
   gui_FindWidget("test_btn_1") <> 0 Then
    backend_Exit()
    End 3
End If

backend_Exit()
Print "single-include registry test OK"
End 0

/' end of automated_tests.bas '/

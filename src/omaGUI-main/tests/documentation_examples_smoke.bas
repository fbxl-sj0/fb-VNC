/'
    Project: omaGUI
    ---------------

    File: documentation_examples_smoke.bas

    Purpose:

        Keep the public manual examples synchronized with the declared API.

    Responsibilities:

        - compile the documented ownership and anchor pattern
        - compile the documented callback signatures
        - exercise documented textbox and imported-combo construction
        - exercise documented aligned, scaled, alpha-aware text output

    This file intentionally does NOT contain:

        - exhaustive widget behavior tests
        - visual screenshot comparisons
        - native window-resize automation
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Dim Shared As Integer documentationButtonChanges
Dim Shared As Integer documentationShapeChanges
Dim Shared As Integer documentationMenuSelection = -1

Sub documentation_OnButton(ByVal clicked As Widget Ptr)
    If clicked <> 0 Then documentationButtonChanges += 1
End Sub

Sub documentation_OnShape(ByVal changed As Widget Ptr)
    If changed <> 0 Then documentationShapeChanges += 1
End Sub

Sub documentation_OnMenu( _
    ByVal context As Any Ptr, ByVal selectedIndex As Integer _
)
    If context <> 0 Then
        *Cast(Integer Ptr, context) = selectedIndex
    End If
End Sub

Dim As Widget Ptr toolWindow
Dim As Widget Ptr runButton
Dim As Widget Ptr editor
Dim As Widget Ptr importedCombo
Dim As Widget Ptr popupMenu

backend_Init 640, 480, 1, BACKEND_WINDOW_RESIZABLE
gui_Init

toolWindow = subwindow_Create("tools", "Tools", 40, 40, 520, 360)
runButton = button_Create( _
    "run", "Run", 12, 14, 80, 28, @documentation_OnButton _
)
editor = textbox_Create( _
    "editor", "Multiline text", 12, 54, 300, 180, _
    -1, -1, TEXTBOX_SCROLLBAR_ALWAYS _
)
importedCombo = graphicshape_Create( _
    "mode", GUI_SHAPE_COMBOBOX, 330, 54, 150, 28, _
    RGB(40, 40, 40), RGB(245, 245, 245), -1, "Mode" _
)
popupMenu = menu_Create("documented_menu", 330, 90)

If toolWindow = 0 OrElse runButton = 0 OrElse editor = 0 OrElse _
   importedCombo = 0 OrElse popupMenu = 0 Then
    backend_Exit
    End 1
End If

gui_AddWidget toolWindow
gui_AddWidget runButton
gui_AddWidget editor
gui_AddWidget importedCombo
gui_AddWidget popupMenu

gui_SetParent runButton, toolWindow
gui_SetParent editor, toolWindow
gui_SetParent importedCombo, toolWindow
gui_SetParent popupMenu, toolWindow

gui_SetAnchors editor, GUI_ANCHOR_LEFT Or GUI_ANCHOR_TOP Or _
    GUI_ANCHOR_RIGHT Or GUI_ANCHOR_BOTTOM

graphicshape_AddItem importedCombo, "Manual"
graphicshape_AddItem importedCombo, "Automatic"
graphicshape_SetInteractive importedCombo, -1, @documentation_OnShape

menu_AddItem popupMenu, "First", 0
menu_SetSelectionHandler _
    popupMenu, @documentation_OnMenu, @documentationMenuSelection
popupMenu->visible = 0

backend_Clear RGB(236, 236, 236)
gui_UpdateAll
gui_RenderAll
backend_PrintAlignedScaledAlpha _
    20, 430, 240, 40, RGB(30, 70, 130), "Status", _
    BACKEND_FONT_ARIAL_12_BOLD, BACKEND_ALIGN_CENTER, _
    BACKEND_ALIGN_MIDDLE, 2, 2, 192
backend_Flip

If textbox_GetVerticalScrollbarMode(editor) <> _
   TEXTBOX_SCROLLBAR_ALWAYS Then
    backend_Exit
    End 2
End If

If graphicshape_IsInteractive(importedCombo) = 0 Then
    backend_Exit
    End 3
End If

gui_RemoveWidget "tools"

If gui_FindWidget("editor") <> 0 OrElse _
   gui_FindWidget("mode") <> 0 OrElse _
   gui_FindWidget("documented_menu") <> 0 Then
    backend_Exit
    End 4
End If

backend_Exit
Print "documentation examples smoke OK"
End 0

/' end of documentation_examples_smoke.bas '/

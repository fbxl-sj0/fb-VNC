/'
    Project: omaGUI
    ---------------
    File: theme.bas
    Purpose: GUI Theme implementation.
'/
#lang "fb"
#include once "src/widgets/widgets.bi"

' -------------------------------------------------------------------------
' Global State
' -------------------------------------------------------------------------

Dim Shared current_theme As GUI_Theme

' -------------------------------------------------------------------------
' Initialization
' -------------------------------------------------------------------------

Sub theme_InitClassic()
    current_theme.bg_face     = RGB(212, 208, 200)
    current_theme.bg_dark     = RGB(128, 128, 128)
    current_theme.bg_light    = RGB(255, 255, 255)
    current_theme.text_main   = RGB(0, 0, 0)
    current_theme.text_select = RGB(255, 255, 255)
    current_theme.bg_select   = RGB(0, 84, 227)
    current_theme.win_border  = RGB(0, 0, 0)
End Sub


Function theme_GetColor(ByVal colorId As Integer) As ULong
    Select Case colorId
        Case GUI_COLOR_BORDER
            Return current_theme.win_border
        Case GUI_COLOR_WINDOW_BG
            Return current_theme.bg_face
        Case GUI_COLOR_WIDGET_BG
            Return current_theme.bg_light
        Case GUI_COLOR_SELECT_BG
            Return current_theme.bg_select
        Case GUI_COLOR_SELECT_TEXT
            Return current_theme.text_select
        Case GUI_COLOR_TEXT
            Return current_theme.text_main
        Case Else
            Return current_theme.text_main
    End Select
End Function

' end of theme.bas

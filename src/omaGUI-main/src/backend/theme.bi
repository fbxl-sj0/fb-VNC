/'
    Project: omaGUI
    ---------------

    File: theme.bi

    Purpose:

        Declare the shared classic widget color theme.

    Responsibilities:

        - define the color fields consumed by standard widgets
        - expose classic-theme initialization and semantic color lookup

    This file intentionally does NOT contain:

        - widget rendering
        - theme persistence or file parsing
        - platform-native appearance discovery
'/

#ifndef __THEME_BI__
#define __THEME_BI__

#include "backend.bi"

Type GUI_Theme
    As ULong bg_face
    As ULong bg_dark
    As ULong bg_light
    As ULong text_main
    As ULong text_select
    As ULong bg_select
    As ULong win_border
End Type

Extern current_theme As GUI_Theme
Declare Sub theme_InitClassic()

Enum GUI_THEME_COLOR
    GUI_COLOR_BORDER = 0
    GUI_COLOR_WINDOW_BG
    GUI_COLOR_WIDGET_BG
    GUI_COLOR_SELECT_BG
    GUI_COLOR_SELECT_TEXT
    GUI_COLOR_TEXT
End Enum

Declare Function theme_GetColor(ByVal colorId As Integer) As ULong

#endif

' end of theme.bi

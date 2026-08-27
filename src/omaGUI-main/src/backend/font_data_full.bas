/'
    Project: omaGUI
    ---------------
    File: font_data_full.bas
    Purpose: Font data storage and initialization.
'/
#lang "fb"
#include once "src/backend/backend.bi"
#include once "src/backend/font_data.bi"

#ifndef __FONT_DATA_FULL_IMPL__
#define __FONT_DATA_FULL_IMPL__
' Shared state boundary: the renderer reads this lookup table after font_init_pointers builds it once.
Dim Shared As UByte Ptr font_chars(32 To 126)
#include "src/backend/font_data_impl.bi"
#include "assets/fonts/font_arial_10_regular.bi"
#include "assets/fonts/font_arial_12_bold.bi"
#endif

Sub font_init_pointers()
    /' Assign character data addresses to the global lookup array '/
    #include "src/backend/font_init.bi"
    font_arial_10_regular_init_pointers()
    font_arial_12_bold_init_pointers()
End Sub

/' end of font_data_full.bas '/

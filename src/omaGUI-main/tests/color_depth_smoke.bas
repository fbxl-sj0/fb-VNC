/'
    Project: omaGUI Test Suite
    --------------------------

    File: color_depth_smoke.bas

    Purpose:

        Verify backend-owned color-mode changes and indexed palettes.

    Responsibilities:

        - verify 8-bit RGB values map to the color cube and grayscale ramp
        - verify 4-bit RGB values map to conventional VGA palette entries
        - verify 1-bit output and palette entries are black and white
        - verify a mode change preserves backend resize state

    This file intentionally does NOT contain:

        - visual screenshot comparison
        - widget interaction tests
        - platform-native window manipulation
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Dim As Integer blueValue
Dim As Integer greenValue
Dim As Integer oldDepth
Dim As ULong pixelValue
Dim As Integer redValue

backend_Init _
    320, 240, -1, BACKEND_WINDOW_RESIZABLE, _
    BACKEND_COLOR_DEPTH_TRUE_COLOR

If backend_IsResizable() = 0 Then
    Print "color depth smoke failed: resize flag was not retained"
    End 11
End If

If backend_SetColorDepth(BACKEND_COLOR_DEPTH_256_COLOR) = 0 OrElse _
   backend_GetColorDepth() <> BACKEND_COLOR_DEPTH_256_COLOR Then
    Print "color depth smoke failed: could not enter 8-bit mode"
    End 12
End If

backend_PSet 10, 10, RGB(255, 0, 0)
pixelValue = Point(10, 10)
If pixelValue <> 180 Then
    Print "color depth smoke failed: 8-bit red index was"; pixelValue
    End 13
End If

backend_PSet 11, 10, RGB(225, 225, 225)
pixelValue = Point(11, 10)
If pixelValue < 216 Then
    Print "color depth smoke failed: neutral gray missed grayscale ramp"
    End 14
End If

Palette Get 255, redValue, greenValue, blueValue
If redValue <> 255 OrElse greenValue <> 255 OrElse blueValue <> 255 Then
    Print "color depth smoke failed: 8-bit white palette entry is wrong"
    End 15
End If

If backend_SetColorDepth(BACKEND_COLOR_DEPTH_16_COLOR) = 0 OrElse _
   backend_GetColorDepth() <> BACKEND_COLOR_DEPTH_16_COLOR Then
    Print "color depth smoke failed: could not enter 4-bit mode"
    End 16
End If

backend_PSet 10, 10, RGB(255, 0, 0)
pixelValue = Point(10, 10)
If pixelValue <> 4 Then
    Print "color depth smoke failed: 4-bit nearest red index was"; pixelValue
    End 17
End If

If backend_SetColorDepth(BACKEND_COLOR_DEPTH_MONOCHROME) = 0 OrElse _
   backend_GetColorDepth() <> BACKEND_COLOR_DEPTH_MONOCHROME Then
    Print "color depth smoke failed: could not enter 1-bit mode"
    End 18
End If

Palette Get 0, redValue, greenValue, blueValue
If redValue <> 0 OrElse greenValue <> 0 OrElse blueValue <> 0 Then
    Print "color depth smoke failed: palette entry 0 is not black"
    End 19
End If

Palette Get 1, redValue, greenValue, blueValue
If redValue <> 255 OrElse greenValue <> 255 OrElse blueValue <> 255 Then
    Print "color depth smoke failed: palette entry 1 is not white"
    End 20
End If

backend_PSet 10, 10, RGB(255, 255, 255)
backend_PSet 11, 10, RGB(0, 0, 0)

If Point(10, 10) <> 1 OrElse Point(11, 10) <> 0 Then
    Print "color depth smoke failed: monochrome pixels were not black/white"
    End 21
End If

oldDepth = backend_GetColorDepth()
If backend_SetColorDepth(24) <> 0 OrElse _
   backend_GetColorDepth() <> oldDepth Then
    Print "color depth smoke failed: unsupported depth changed the screen"
    End 22
End If

If backend_IsResizable() = 0 Then
    Print "color depth smoke failed: mode changes lost resize support"
    End 1
End If

backend_Exit
Print "color depth smoke OK"
End 0

/' end of color_depth_smoke.bas '/

/'
    Project: omaGUI Test Suite
    --------------------------

    File: alpha_render_smoke.bas

    Purpose:

        Verify true-color alpha compositing used by the feature demo.

    Responsibilities:

        - prove per-pixel alpha blends source and destination color channels
        - prove imported graphic object alpha reaches its filled geometry
        - prove fully transparent pixels preserve the destination

    This file intentionally does NOT contain:

        - indexed-color alpha expectations
        - screenshot comparison
        - interactive control tests
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Private Sub alphaRender_Fail( _
    ByVal messageText As String, ByVal exitCode As Integer _
)
    backend_Exit
    Print "alpha render smoke failed: " & messageText
    End exitCode
End Sub


Private Function alphaRender_Channel( _
    ByVal pixelValue As ULong, ByVal shiftValue As Integer _
) As Integer
    Return (pixelValue Shr shiftValue) And &HFF
End Function


Dim As ULong pixelValue
Dim As GraphicShapeRenderOptions shapeOptions
Dim As Integer unusedPointX(1 To GRAPHICSHAPE_MAX_POINTS)
Dim As Integer unusedPointY(1 To GRAPHICSHAPE_MAX_POINTS)

backend_Init 96, 72, -1, 0, BACKEND_COLOR_DEPTH_TRUE_COLOR
backend_Clear RGB(0, 0, 0)

backend_PSetAlpha 10, 10, RGB(255, 128, 0), 128
pixelValue = Point(10, 10)

If alphaRender_Channel(pixelValue, 16) <> 128 OrElse _
   alphaRender_Channel(pixelValue, 8) <> 64 OrElse _
   alphaRender_Channel(pixelValue, 0) <> 0 Then
    alphaRender_Fail "per-pixel 50 percent blend was wrong", 1
End If

backend_PSetAlpha 11, 10, RGB(255, 255, 255), 0
If Point(11, 10) <> RGB(0, 0, 0) Then
    alphaRender_Fail "zero alpha changed its destination pixel", 2
End If

graphicshape_DefaultOptions shapeOptions, GUI_SHAPE_RECTANGLE
shapeOptions.stroke_clr = RGB(0, 0, 0)
shapeOptions.fill_clr = RGB(0, 128, 255)
shapeOptions.fill_gradient_clr = shapeOptions.fill_clr
shapeOptions.filled = -1
shapeOptions.fill_mode = GUI_FILL_SOLID
shapeOptions.line_width = 0
shapeOptions.object_alpha = 128
shapeOptions.fill_alpha = 255

graphicshape_RenderWithOptions _
    20, 20, 12, 12, shapeOptions, "", 0, _
    unusedPointX(), unusedPointY()
pixelValue = Point(25, 25)

If alphaRender_Channel(pixelValue, 16) <> 0 OrElse _
   alphaRender_Channel(pixelValue, 8) <> 64 OrElse _
   alphaRender_Channel(pixelValue, 0) <> 128 Then
    alphaRender_Fail "graphic object alpha did not blend its fill", 3
End If

backend_Exit
Print "alpha render smoke OK"
End 0

/' end of alpha_render_smoke.bas '/

/'
    Project: omaGUI
    ---------------

    File: restored_widgets_smoke.bas

    Purpose:

        Verify the restored primitive and advanced graphic widget surface.

    Responsibilities:

        - construct and render every restored widget family
        - verify parent-relative coordinates for restored widgets
        - exercise advanced graphic style and path setters
        - exercise the restored alpha, font, and alignment backend API

    This file intentionally does NOT contain:

        - visual screenshot comparisons
        - interactive application behavior
        - performance benchmarking
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Const RESTORED_SMOKE_WIDTH As Integer = 640
Const RESTORED_SMOKE_HEIGHT As Integer = 480

Sub restoredWidgets_Fail(ByVal messageText As String, ByVal exitCode As Integer)
    Print "restored widgets smoke failed: "; messageText
    backend_Exit()
    End exitCode
End Sub

Dim As Widget Ptr parentWindow
Dim As Widget Ptr lineWidget
Dim As Widget Ptr rectangleWidget
Dim As Widget Ptr circleWidget
Dim As Widget Ptr curveWidget
Dim As Widget Ptr styledShape
Dim As Widget Ptr pathShape
Dim As Widget Ptr currentShape
Dim As GraphicShapeData Ptr shapeData
Dim As GraphicShapeRenderOptions options
Dim As Integer gradientPositions(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS)
Dim As ULong gradientColors(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS)
Dim As Integer pathX(1 To GRAPHICSHAPE_MAX_POINTS)
Dim As Integer pathY(1 To GRAPHICSHAPE_MAX_POINTS)

backend_Init RESTORED_SMOKE_WIDTH, RESTORED_SMOKE_HEIGHT, 1
gui_Init()

parentWindow = subwindow_Create("restored_parent", "Restored", 30, 20, 560, 420)
lineWidget = linewidget_Create("restored_line", 5, 6, 80, 36, RGB(255, 0, 0))
rectangleWidget = rectwidget_Create( _
    "restored_rectangle", 90, 6, 60, 30, RGB(0, 160, 0), 1 _
)
circleWidget = circlewidget_Create( _
    "restored_circle", 160, 6, 15, RGB(0, 0, 255), 1 _
)
curveWidget = curvewidget_Create( _
    "restored_curve", 200, 35, 245, 0, 290, 35, RGB(180, 0, 180) _
)

If parentWindow = 0 OrElse lineWidget = 0 OrElse rectangleWidget = 0 OrElse _
   circleWidget = 0 OrElse curveWidget = 0 Then
    restoredWidgets_Fail "primitive constructor returned null", 1
End If

gui_AddWidget parentWindow
gui_AddWidget lineWidget
gui_AddWidget rectangleWidget
gui_AddWidget circleWidget
gui_AddWidget curveWidget
gui_SetParent lineWidget, parentWindow
gui_SetParent rectangleWidget, parentWindow
gui_SetParent circleWidget, parentWindow
gui_SetParent curveWidget, parentWindow

graphicshape_DefaultOptions options, GUI_SHAPE_ROUNDED_RECTANGLE
options.stroke_clr = RGB(20, 30, 40)
options.fill_clr = RGB(220, 225, 230)
options.fill_gradient_clr = RGB(80, 120, 180)
options.text_clr = RGB(0, 0, 0)
options.filled = 1
options.fill_mode = GUI_FILL_GRADIENT_VERTICAL
options.line_width = 2
options.corner_radius = 9
options.clip_to_bounds = 1

styledShape = graphicshape_CreateWithOptions( _
    "restored_styled", 310, 6, 120, 50, options, "Styled" _
)

If styledShape = 0 Then
    restoredWidgets_Fail "styled graphic constructor returned null", 2
End If

gui_AddWidget styledShape
gui_SetParent styledShape, parentWindow

gradientPositions(1) = 0
gradientPositions(2) = 10000
gradientColors(1) = RGB(255, 255, 255)
gradientColors(2) = RGB(0, 80, 160)
graphicshape_SetFillGradientStops styledShape, 2, _
    gradientPositions(), gradientColors()
graphicshape_SetObjectAlpha styledShape, 230
graphicshape_SetStrokeAlpha styledShape, 210
graphicshape_SetFillAlpha styledShape, 190
graphicshape_SetCornerRadius styledShape, 12
graphicshape_SetClipToBounds styledShape, 1

shapeData = Cast(GraphicShapeData Ptr, styledShape->data)

If shapeData->fill_gradient_stop_count <> 2 OrElse _
   shapeData->object_alpha <> 230 OrElse shapeData->corner_radius <> 12 Then
    restoredWidgets_Fail "style setters did not update graphic data", 3
End If

pathShape = graphicshape_Create( _
    "restored_path", GUI_SHAPE_POLYGON, 10, 70, 100, 60, _
    RGB(0, 0, 0), RGB(210, 180, 120), 1, "" _
)
gui_AddWidget pathShape
gui_SetParent pathShape, parentWindow
graphicshape_SetPathPoint pathShape, 1, 0, 50
graphicshape_SetPathPoint pathShape, 2, 50, 0
graphicshape_SetPathPoint pathShape, 3, 100, 50

For shapeKind As Integer = GUI_SHAPE_LINE To GUI_SHAPE_EMBEDDED_SYMBOL
    currentShape = graphicshape_Create( _
        "restored_kind_" & LTrim(Str(shapeKind)), shapeKind, _
        10 + ((shapeKind - 1) Mod 7) * 70, _
        150 + ((shapeKind - 1) \ 7) * 55, _
        58, 38, RGB(40, 40, 40), RGB(220, 220, 220), 1, _
        "K" & LTrim(Str(shapeKind)) _
    )

    If currentShape = 0 Then
        restoredWidgets_Fail "graphic kind constructor returned null", 4
    End If

    gui_AddWidget currentShape
    gui_SetParent currentShape, parentWindow
Next shapeKind

pathX(1) = 0
pathY(1) = 20
pathX(2) = 20
pathY(2) = 0
pathX(3) = 40
pathY(3) = 20
graphicshape_DefaultOptions options, GUI_SHAPE_POLYLINE
graphicshape_RenderWithOptions 500, 430, 40, 20, options, "", 3, _
    pathX(), pathY()

gui_UpdateAll()

If lineWidget->ax <> 35 OrElse lineWidget->ay <> 26 Then
    restoredWidgets_Fail "primitive widget ignored its parent offset", 5
End If

If styledShape->ax <> 340 OrElse styledShape->ay <> 26 Then
    restoredWidgets_Fail "advanced graphic ignored its parent offset", 6
End If

backend_Clear RGB(240, 240, 240)
gui_RenderAll()
backend_LineEx 4, 450, 120, 450, RGB(0, 0, 0), 3, 180
backend_RectEx 130, 438, 80, 24, RGB(40, 100, 180), 1, 2, 160
backend_PSetAlpha 220, 450, RGB(255, 0, 0), 128
backend_PrintScaledFontAlpha 230, 442, RGB(0, 0, 0), "Scale", _
    BACKEND_FONT_ARIAL_10_REGULAR, 1, 1, 220
backend_PrintAligned 300, 438, 120, 24, RGB(0, 0, 0), "Aligned", _
    BACKEND_FONT_ARIAL_12_BOLD, BACKEND_ALIGN_CENTER, BACKEND_ALIGN_MIDDLE

If backend_GetTextWidthFont("Test", BACKEND_FONT_ARIAL_10_REGULAR) <= 0 OrElse _
   backend_GetTextHeightFont(BACKEND_FONT_ARIAL_12_BOLD) <= 0 Then
    restoredWidgets_Fail "restored font measurement API returned no size", 7
End If

gui_RemoveWidget "restored_parent"

If gui_FindWidget("restored_line") <> 0 OrElse _
   gui_FindWidget("restored_styled") <> 0 OrElse _
   gui_FindWidget("restored_kind_28") <> 0 Then
    restoredWidgets_Fail "parent removal left a restored child registered", 8
End If

backend_Exit()
Print "restored widgets smoke OK"
End 0

/' end of restored_widgets_smoke.bas '/

/'
    Project: omaGUI
    ---------------

    File: curvewidget.bi

    Purpose:

        Declare a registry-managed quadratic curve drawing widget.

    Responsibilities:

        - retain a control point and curve color
        - represent endpoints through the base widget rectangle

    This file intentionally does NOT contain:

        - curve rasterization
        - cubic Bezier or spline behavior
'/

#ifndef __CURVEWIDGET_BI__
#define __CURVEWIDGET_BI__

#include once "src/widgets/widgets.bi"

Type CurveWidgetData
    As Integer cx, cy
    As ULong clr
End Type

Declare Function curvewidget_Create( _
    ByVal nm As String, _
    ByVal x1 As Integer, ByVal y1 As Integer, _
    ByVal cx As Integer, ByVal cy As Integer, _
    ByVal x2 As Integer, ByVal y2 As Integer, _
    ByVal clr As ULong _
) As Widget Ptr
Declare Sub curvewidget_Render(ByVal w As Widget Ptr)
Declare Sub curvewidget_Destroy(ByVal w As Widget Ptr)

#endif

' end of curvewidget.bi

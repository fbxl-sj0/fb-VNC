/'
    Project: omaGUI
    ---------------

    File: circlewidget.bi

    Purpose:

        Declare a registry-managed circle drawing widget.

    Responsibilities:

        - retain radius, color, and fill state
        - expose circle creation and rendering lifecycle entry points

    This file intentionally does NOT contain:

        - circle rasterization
        - interactive geometry editing
'/

#ifndef __CIRCLEWIDGET_BI__
#define __CIRCLEWIDGET_BI__

#include once "src/widgets/widgets.bi"

Type CircleWidgetData
    As Integer r
    As ULong clr
    As Integer filled
End Type

Declare Function circlewidget_Create( _
    ByVal nm As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal r As Integer, ByVal clr As ULong, _
    ByVal filled As Integer _
) As Widget Ptr
Declare Sub circlewidget_Render(ByVal w As Widget Ptr)
Declare Sub circlewidget_Destroy(ByVal w As Widget Ptr)

#endif

' end of circlewidget.bi

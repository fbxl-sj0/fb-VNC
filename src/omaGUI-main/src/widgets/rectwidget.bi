/'
    Project: omaGUI
    ---------------

    File: rectwidget.bi

    Purpose:

        Declare a registry-managed rectangle drawing widget.

    Responsibilities:

        - retain rectangle color and fill state
        - expose rectangle creation and rendering lifecycle entry points

    This file intentionally does NOT contain:

        - rectangle rasterization
        - interactive resize handles
'/

#ifndef __RECTWIDGET_BI__
#define __RECTWIDGET_BI__

#include once "src/widgets/widgets.bi"

Type RectWidgetData
    As ULong clr
    As Integer filled
End Type

Declare Function rectwidget_Create( _
    ByVal nm As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal clr As ULong, ByVal filled As Integer _
) As Widget Ptr
Declare Sub rectwidget_Render(ByVal w As Widget Ptr)
Declare Sub rectwidget_Destroy(ByVal w As Widget Ptr)

#endif

' end of rectwidget.bi

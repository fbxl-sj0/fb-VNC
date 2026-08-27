/'
    Project: omaGUI
    ---------------

    File: circlewidget.bas

    Purpose:

        Implement a registry-managed circle drawing widget.

    Responsibilities:

        - resolve the stored top-left position into a circle center
        - render filled or outlined circles through the backend
        - release circle-specific state

    This file intentionally does NOT contain:

        - circle rasterization
        - pointer interaction
'/

#lang "fb"
#include once "src/widgets/circlewidget.bi"
Sub circlewidget_Render(ByVal w As Widget Ptr)
    Dim As CircleWidgetData Ptr d = w->data
    backend_Circle(w->ax + d->r, w->ay + d->r, d->r, d->clr, d->filled)
End Sub
Sub circlewidget_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then Delete Cast(CircleWidgetData Ptr, w->data)
End Sub
Function circlewidget_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer, ByVal r As Integer, ByVal clr As ULong, ByVal filled As Integer) As Widget Ptr
    Dim As Widget Ptr res = New Widget
    res->name = nm : res->x = x : res->y = y : res->w = r * 2 : res->h = r * 2
    res->render = @circlewidget_Render : res->destroy = @circlewidget_Destroy
    res->visible = 1 : res->enabled = 1
    Dim As CircleWidgetData Ptr d = New CircleWidgetData
    d->r = r : d->clr = clr : d->filled = filled : res->data = d : Return res
End Function

' end of circlewidget.bas

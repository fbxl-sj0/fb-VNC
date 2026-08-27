/'
    Project: omaGUI
    ---------------

    File: curvewidget.bas

    Purpose:

        Implement a registry-managed quadratic curve drawing widget.

    Responsibilities:

        - resolve parent-relative endpoints and the stored control point
        - render the curve through the graphics backend
        - release curve-specific state

    This file intentionally does NOT contain:

        - curve rasterization
        - cubic Bezier or spline behavior
'/

#lang "fb"
#include once "src/widgets/curvewidget.bi"
Sub curvewidget_Render(ByVal w As Widget Ptr)
    Dim As CurveWidgetData Ptr d = w->data
    backend_Curve(w->ax, w->ay, w->ax + d->cx, w->ay + d->cy, w->ax + w->w, w->ay + w->h, d->clr)
End Sub
Sub curvewidget_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then Delete Cast(CurveWidgetData Ptr, w->data)
End Sub
Function curvewidget_Create(ByVal nm As String, ByVal x1 As Integer, ByVal y1 As Integer, ByVal cx As Integer, ByVal cy As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal clr As ULong) As Widget Ptr
    Dim As Widget Ptr res = New Widget
    res->name = nm : res->x = x1 : res->y = y1 : res->w = x2 - x1 : res->h = y2 - y1
    res->render = @curvewidget_Render : res->destroy = @curvewidget_Destroy
    res->visible = 1 : res->enabled = 1
    Dim As CurveWidgetData Ptr d = New CurveWidgetData
    d->cx = cx - x1 : d->cy = cy - y1 : d->clr = clr : res->data = d : Return res
End Function

' end of curvewidget.bas

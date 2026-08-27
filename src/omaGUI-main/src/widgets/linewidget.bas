/'
    Project: omaGUI
    ---------------

    File: linewidget.bas

    Purpose:

        Implement a registry-managed line drawing widget.

    Responsibilities:

        - convert the base widget rectangle into two endpoints
        - render the line through the graphics backend
        - release line-specific state

    This file intentionally does NOT contain:

        - line rasterization
        - pointer interaction
'/

#lang "fb"
#include once "src/widgets/linewidget.bi"
Sub linewidget_Render(ByVal w As Widget Ptr)
    Dim As LineWidgetData Ptr d = w->data
    backend_Line(w->ax, w->ay, w->ax + w->w, w->ay + w->h, d->clr)
End Sub
Sub linewidget_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then Delete Cast(LineWidgetData Ptr, w->data)
End Sub
Function linewidget_Create(ByVal nm As String, ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal clr As ULong) As Widget Ptr
    Dim As Widget Ptr res = New Widget
    res->name = nm : res->x = x1 : res->y = y1 : res->w = x2 - x1 : res->h = y2 - y1
    res->render = @linewidget_Render : res->destroy = @linewidget_Destroy
    res->visible = 1 : res->enabled = 1
    Dim As LineWidgetData Ptr d = New LineWidgetData
    d->clr = clr : res->data = d : Return res
End Function

' end of linewidget.bas

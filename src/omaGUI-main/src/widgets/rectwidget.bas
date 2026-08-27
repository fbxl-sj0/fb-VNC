/'
    Project: omaGUI
    ---------------

    File: rectwidget.bas

    Purpose:

        Implement a registry-managed rectangle drawing widget.

    Responsibilities:

        - render filled or outlined rectangles through the backend
        - release rectangle-specific state

    This file intentionally does NOT contain:

        - rectangle rasterization
        - interactive resize behavior
'/

#lang "fb"
#include once "src/widgets/rectwidget.bi"
Sub rectwidget_Render(ByVal w As Widget Ptr)
    Dim As RectWidgetData Ptr d = w->data
    backend_Rect(w->ax, w->ay, w->w, w->h, d->clr, d->filled)
End Sub
Sub rectwidget_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then Delete Cast(RectWidgetData Ptr, w->data)
End Sub
Function rectwidget_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, ByVal filled As Integer) As Widget Ptr
    Dim As Widget Ptr res = New Widget
    res->name = nm : res->x = x : res->y = y : res->w = w : res->h = h
    res->render = @rectwidget_Render : res->destroy = @rectwidget_Destroy
    res->visible = 1 : res->enabled = 1
    Dim As RectWidgetData Ptr d = New RectWidgetData
    d->clr = clr : d->filled = filled : res->data = d : Return res
End Function

' end of rectwidget.bas

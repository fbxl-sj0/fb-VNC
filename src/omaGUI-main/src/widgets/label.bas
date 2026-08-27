/'
    Project: omaGUI
    ---------------
    File: label.bas

    Purpose:
        Label widget implementation.

    Responsibilities:
         Render static text with customizable colors
'/

#lang "fb"
#include once "src/widgets/label.bi"

' -------------------------------------------------------------------------
' Construction
' -------------------------------------------------------------------------

Function label_Create(ByVal nm As String, ByVal txt As String, ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As LabelData Ptr d = New LabelData

    wgt->name = nm : wgt->x = x : wgt->y = y : wgt->visible = 1 : wgt->enabled = 1 : wgt->render = @label_Render : wgt->update = 0 : wgt->destroy = @label_Destroy

    d->text = txt : d->clr = clr

    wgt->data = d
    Return wgt
End Function

' -------------------------------------------------------------------------
' Rendering
' -------------------------------------------------------------------------

Sub label_Render(ByVal w As Widget Ptr)
    Dim As LabelData Ptr d = w->data
    backend_Print(w->ax, w->ay, d->clr, d->text)
End Sub

' -------------------------------------------------------------------------
' Lifecycle
' -------------------------------------------------------------------------

Sub label_Destroy(ByVal w As Widget Ptr)
    Delete Cast(LabelData Ptr, w->data)
End Sub

' end of label.bas

/'
    Project: omaGUI
    ---------------
    File: checkbox.bas

    Purpose:
        Checkbox widget implementation.

    Responsibilities:
         Render standard checkbox with bevel effects
         Handle toggle interactions via mouse
         Manage internal Checked state
'/

#lang "fb"
#include once "src/widgets/checkbox.bi"
#include once "src/backend/theme.bi"

Const CHECKBOX_SIZE As Integer = 12
Const CHECKBOX_BORDER_WIDTH As Integer = 1
Const CHECKBOX_INNER_SIZE As Integer = CHECKBOX_SIZE - CHECKBOX_BORDER_WIDTH * 2
Const CHECKBOX_TICK_INSET As Integer = CHECKBOX_BORDER_WIDTH * 2
Const CHECKBOX_TICK_END_OFFSET As Integer = CHECKBOX_SIZE - CHECKBOX_TICK_INSET - 1

' -------------------------------------------------------------------------
' Construction
' -------------------------------------------------------------------------

Function checkbox_Create(ByVal nm As String, ByVal lbl As String, ByVal x As Integer, ByVal y As Integer, ByVal checked As Integer) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As CheckBoxData Ptr d = New CheckBoxData

    wgt->name = nm : wgt->x = x : wgt->y = y : wgt->w = CHECKBOX_SIZE : wgt->h = CHECKBOX_SIZE
    wgt->visible = 1 : wgt->enabled = 1 : wgt->render = @checkbox_Render : wgt->update = @checkbox_Update : wgt->destroy = @checkbox_Destroy

    d->label = lbl : d->checked = checked : d->last_mb = 0

    wgt->data = d
    Return wgt
End Function

' -------------------------------------------------------------------------
' Rendering
' -------------------------------------------------------------------------

Sub checkbox_Render(ByVal w As Widget Ptr)
    Dim As CheckBoxData Ptr d = w->data

    backend_Rect(w->ax, w->ay, CHECKBOX_SIZE, CHECKBOX_SIZE, current_theme.bg_dark, 0)
    backend_Rect(w->ax + CHECKBOX_BORDER_WIDTH, w->ay + CHECKBOX_BORDER_WIDTH, CHECKBOX_INNER_SIZE, CHECKBOX_INNER_SIZE, current_theme.bg_light, 1)

    If d->checked Then
        backend_Line(w->ax + CHECKBOX_TICK_INSET, w->ay + CHECKBOX_TICK_INSET, w->ax + CHECKBOX_TICK_END_OFFSET, w->ay + CHECKBOX_TICK_END_OFFSET, current_theme.text_main)
        backend_Line(w->ax + CHECKBOX_TICK_END_OFFSET, w->ay + CHECKBOX_TICK_INSET, w->ax + CHECKBOX_TICK_INSET, w->ay + CHECKBOX_TICK_END_OFFSET, current_theme.text_main)
    End If

    backend_Print(w->ax + 16, w->ay, current_theme.text_main, d->label)
End Sub

' -------------------------------------------------------------------------
' Processing
' -------------------------------------------------------------------------

Sub checkbox_Update(ByVal w As Widget Ptr)
    Dim As CheckBoxData Ptr d = w->data
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = (input_MouseButtons() And 1)

    If (mb <> 0) And (d->last_mb = 0) Then
        If mx >= w->ax And mx < w->ax + CHECKBOX_SIZE And my >= w->ay And my < w->ay + CHECKBOX_SIZE Then
            d->checked = Not d->checked
        End If
    End If
    d->last_mb = mb
End Sub

' -------------------------------------------------------------------------
' Lifecycle
' -------------------------------------------------------------------------

Sub checkbox_Destroy(ByVal w As Widget Ptr)
    Delete Cast(CheckBoxData Ptr, w->data)
End Sub

' end of checkbox.bas

/'
    Project: omaGUI
    ---------------
    File: radiobox.bas

    Purpose:
        RadioBox widget implementation with exclusivity logic.

    Responsibilities:
        - Render circular selection buttons
        - Manage exclusive group selection logic
'/

#lang "fb"

#include once "src/widgets/radiobox.bi"
#include once "src/backend/theme.bi"

Const RADIOBOX_DIAMETER As Integer = 12
Const RADIOBOX_CENTER_OFFSET As Integer = RADIOBOX_DIAMETER \ 2
Const RADIOBOX_OUTER_RADIUS As Integer = RADIOBOX_CENTER_OFFSET
Const RADIOBOX_INNER_RADIUS As Integer = RADIOBOX_OUTER_RADIUS - 1
Const RADIOBOX_SELECTED_RADIUS As Integer = RADIOBOX_INNER_RADIUS - 2
Const RADIOBOX_SELECTED_RADIUS_SQUARED As Integer = RADIOBOX_SELECTED_RADIUS * RADIOBOX_SELECTED_RADIUS

' -------------------------------------------------------------------------
' Construction
' -------------------------------------------------------------------------

Function radiobox_Create(ByVal nm As String, ByVal lbl As String, ByVal x As Integer, ByVal y As Integer, ByVal gid As Integer, ByVal s As Integer) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As RadioBoxData Ptr d = New RadioBoxData

    wgt->name = nm : wgt->x = x : wgt->y = y : wgt->w = RADIOBOX_DIAMETER : wgt->h = RADIOBOX_DIAMETER
    wgt->visible = 1 : wgt->enabled = 1 : wgt->render = @radiobox_Render : wgt->update = @radiobox_Update : wgt->destroy = @radiobox_Destroy

    d->label = lbl : d->group_id = gid : d->selected = s : d->last_mb = 0

    wgt->data = d
    Return wgt
End Function

' -------------------------------------------------------------------------
' Rendering
' -------------------------------------------------------------------------

Sub radiobox_Render(ByVal w As Widget Ptr)
    Dim As RadioBoxData Ptr d = w->data

    backend_Circle(w->ax + RADIOBOX_CENTER_OFFSET, w->ay + RADIOBOX_CENTER_OFFSET, RADIOBOX_OUTER_RADIUS, current_theme.bg_dark, 0)
    backend_Circle(w->ax + RADIOBOX_CENTER_OFFSET, w->ay + RADIOBOX_CENTER_OFFSET, RADIOBOX_INNER_RADIUS, current_theme.bg_light, 1)

    If d->selected Then
        backend_Circle(w->ax + RADIOBOX_CENTER_OFFSET, w->ay + RADIOBOX_CENTER_OFFSET, RADIOBOX_SELECTED_RADIUS, current_theme.text_main, 1)
    End If

    backend_Print(w->ax + 16, w->ay, current_theme.text_main, d->label)
End Sub

' -------------------------------------------------------------------------
' Processing
' -------------------------------------------------------------------------

Sub radiobox_Update(ByVal w As Widget Ptr)
    Dim As RadioBoxData Ptr d = w->data
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = (input_MouseButtons() And 1)

    If (mb <> 0) And (d->last_mb = 0) Then
        Dim As Integer dx = mx - (w->ax + RADIOBOX_CENTER_OFFSET)
        Dim As Integer dy = my - (w->ay + RADIOBOX_CENTER_OFFSET)
        If (dx*dx + dy*dy) <= RADIOBOX_SELECTED_RADIUS_SQUARED Then
            d->selected = 1
            gui_DeselectRadioGroup(d->group_id, w)
        End If
    End If
    d->last_mb = mb
End Sub

' -------------------------------------------------------------------------
' Lifecycle
' -------------------------------------------------------------------------

Sub radiobox_Destroy(ByVal w As Widget Ptr)
    Delete Cast(RadioBoxData Ptr, w->data)
End Sub

' end of radiobox.bas

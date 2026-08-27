/'
    Project: omaGUI
    ---------------

    File: button.bas

    Purpose:

        Implement the classic push-button widget.

    Responsibilities:

        - render normal, hover, and pressed button states
        - convert a completed pointer press into one activation
        - invoke the optional application callback

    This file intentionally does NOT contain:

        - global pointer routing
        - application command policy
'/

#lang "fb"
#include once "src/widgets/button.bi"
#include once "src/backend/theme.bi"
Function button_Create(ByVal nm As String, ByVal txt As String, ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal clickHandler As Any Ptr) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As ButtonData Ptr d = New ButtonData
    wgt->name = nm
    wgt->x = x
    wgt->y = y
    wgt->w = w
    wgt->h = h
    wgt->visible = 1
    wgt->enabled = 1
    wgt->render = @button_Render
    wgt->update = @button_Update
    wgt->destroy = @button_Destroy
    d->text = txt
    d->pressed = 0
    d->state = 0
    d->clickHandler = clickHandler
    wgt->data = d
    Return wgt
End Function
Sub button_Render(ByVal w As Widget Ptr)
    Const BUTTON_EDGE_INSET As Integer = 1
    Const BUTTON_BEVEL_REDUCTION As Integer = 2
    Const BUTTON_INNER_BEVEL_REDUCTION As Integer = 3
    Const BUTTON_FACE_INSET As Integer = 2
    Const BUTTON_FACE_REDUCTION As Integer = 4
    Const BUTTON_TEXT_HEIGHT As Integer = 12
    Dim As ButtonData Ptr d = w->data
    Dim As ULong c_f = current_theme.bg_face
    Dim As ULong c_d = current_theme.bg_dark
    Dim As ULong c_l = current_theme.bg_light
    If d->state = 2 Then Swap c_d, c_l
    backend_Rect(w->ax, w->ay, w->w, w->h, current_theme.win_border, 0)
    backend_Rect(w->ax+BUTTON_EDGE_INSET, w->ay+BUTTON_EDGE_INSET, w->w-BUTTON_BEVEL_REDUCTION, w->h-BUTTON_BEVEL_REDUCTION, c_l, 0)
    backend_Rect(w->ax+BUTTON_EDGE_INSET, w->ay+BUTTON_EDGE_INSET, w->w-BUTTON_INNER_BEVEL_REDUCTION, w->h-BUTTON_INNER_BEVEL_REDUCTION, c_l, 0)
    backend_Line(w->ax+BUTTON_EDGE_INSET, w->ay+w->h-BUTTON_BEVEL_REDUCTION, w->ax+w->w-BUTTON_BEVEL_REDUCTION, w->ay+w->h-BUTTON_BEVEL_REDUCTION, c_d)
    backend_Line(w->ax+w->w-BUTTON_BEVEL_REDUCTION, w->ay+BUTTON_EDGE_INSET, w->ax+w->w-BUTTON_BEVEL_REDUCTION, w->ay+w->h-BUTTON_BEVEL_REDUCTION, c_d)
    backend_Rect(w->ax+BUTTON_FACE_INSET, w->ay+BUTTON_FACE_INSET, w->w-BUTTON_FACE_REDUCTION, w->h-BUTTON_FACE_REDUCTION, c_f, 1)
    backend_Print(w->ax + (w->w - backend_GetTextWidth(d->text)) \ 2, w->ay + (w->h - BUTTON_TEXT_HEIGHT) \ 2, current_theme.text_main, d->text)
End Sub
Sub button_Update(ByVal w As Widget Ptr)
    Dim As ButtonData Ptr d = w->data
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = input_MouseButtons()
    d->pressed = 0
    If mx >= w->ax And mx < w->ax + w->w And my >= w->ay And my < w->ay + w->h Then
        If mb And 1 Then
            d->state = 2
        Else
            If d->state = 2 Then
                d->pressed = 1
                If d->clickHandler <> 0 Then
                    Cast(Sub(ByVal As Widget Ptr), d->clickHandler)(w)
                End If
            End If
            d->state = 1
        End If
    Else
        d->state = 0
    End If
End Sub
Sub button_Destroy(ByVal w As Widget Ptr)
    Delete Cast(ButtonData Ptr, w->data)
End Sub
Function gui_ButtonPressed(ByVal nm As String) As Integer
    Dim As Widget Ptr w = gui_FindWidget(nm)
    If w = 0 Then Return 0
    Dim As ButtonData Ptr d = w->data
    Return d->pressed
End Function

' end of button.bas

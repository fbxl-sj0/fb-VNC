/'
    Project: omaGUI
    ---------------
    File: scrollbar.bas

    Purpose:
        ScrollBar widget implementation.

    Responsibilities:
         Render a proportional scroll track and thumb
         Handle value updates through dragging and the mouse wheel

    This file intentionally does NOT contain:
         List selection behavior
         Global pointer dispatch policy
'/

#lang "fb"
#include once "src/widgets/scrollbar.bi"
#include once "src/backend/theme.bi"

Const SCROLLBAR_MINIMUM_THUMB_SIZE As Integer = 12
Const SCROLLBAR_MINIMUM_WHEEL_STEP As Integer = 1

Private Sub scrollbar_ClampValue(ByVal scrollData As ScrollBarData Ptr)
    If scrollData = 0 Then Exit Sub
    If scrollData->max_val < 0 Then scrollData->max_val = 0
    If scrollData->value < 0 Then scrollData->value = 0
    If scrollData->value > scrollData->max_val Then _
        scrollData->value = scrollData->max_val
End Sub

' -------------------------------------------------------------------------
' Construction
' -------------------------------------------------------------------------

Function scrollbar_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal mv As Integer, ByVal ps As Integer, ByVal v As Integer) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As ScrollBarData Ptr d = New ScrollBarData

    wgt->name = nm : wgt->x = x : wgt->y = y : wgt->w = w : wgt->h = h
    wgt->visible = 1 : wgt->enabled = 1 : wgt->render = @scrollbar_Render : wgt->update = @scrollbar_Update : wgt->destroy = @scrollbar_Destroy

    d->value = 0 : d->max_val = mv : d->page_size = ps : d->vertical = v

    wgt->data = d
    Return wgt
End Function

' -------------------------------------------------------------------------
' Rendering
' -------------------------------------------------------------------------

Sub scrollbar_Render(ByVal w As Widget Ptr)
    Dim As ScrollBarData Ptr d = w->data
    Dim As Integer scrollExtent
    Dim As Integer thumbPosition
    Dim As Integer thumbSize
    Dim As Integer trackLength

    If w = 0 OrElse d = 0 Then Exit Sub
    scrollbar_ClampValue d

    /'
        A zero-range scrollbar remains visible for controls using an
        always-present policy, but its uniform face color communicates that
        there is no movable content.
    '/
    If d->max_val = 0 OrElse w->enabled = 0 Then
        backend_Rect w->ax, w->ay, w->w, w->h, current_theme.bg_face, 1
        backend_Rect w->ax, w->ay, w->w, w->h, current_theme.bg_dark, 0
        Exit Sub
    End If

    ' Track
    backend_Rect(w->ax, w->ay, w->w, w->h, current_theme.bg_dark, 1)

    If d->vertical Then
        trackLength = w->h
    Else
        trackLength = w->w
    End If

    If trackLength < 1 Then Exit Sub

    thumbSize = (d->page_size * trackLength) \ _
        (d->max_val + d->page_size)
    If thumbSize < SCROLLBAR_MINIMUM_THUMB_SIZE Then _
        thumbSize = SCROLLBAR_MINIMUM_THUMB_SIZE
    If thumbSize > trackLength Then thumbSize = trackLength

    scrollExtent = trackLength - thumbSize
    If scrollExtent > 0 Then
        thumbPosition = (d->value * scrollExtent) \ d->max_val
    End If

    If d->vertical Then
        backend_Rect w->ax + 2, w->ay + thumbPosition, _
            w->w - 4, thumbSize, current_theme.bg_face, 1
        backend_Rect w->ax + 2, w->ay + thumbPosition, _
            w->w - 4, thumbSize, current_theme.bg_light, 0
    Else
        backend_Rect w->ax + thumbPosition, w->ay + 2, _
            thumbSize, w->h - 4, current_theme.bg_face, 1
        backend_Rect w->ax + thumbPosition, w->ay + 2, _
            thumbSize, w->h - 4, current_theme.bg_light, 0
    End If
End Sub

' -------------------------------------------------------------------------
' Processing
' -------------------------------------------------------------------------

Sub scrollbar_Update(ByVal w As Widget Ptr)
    Dim As ScrollBarData Ptr d = w->data
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = input_MouseButtons()
    Dim As Integer wheelDelta = input_MouseWheel()
    Dim As Integer wheelStep

    If w = 0 OrElse d = 0 OrElse w->enabled = 0 Then Exit Sub

    If mx >= w->ax AndAlso mx < w->ax + w->w AndAlso _
       my >= w->ay AndAlso my < w->ay + w->h Then
        If wheelDelta <> 0 Then
            wheelStep = d->page_size \ 3
            If wheelStep < SCROLLBAR_MINIMUM_WHEEL_STEP Then _
                wheelStep = SCROLLBAR_MINIMUM_WHEEL_STEP
            d->value -= wheelDelta * wheelStep
        End If

        If mb And 1 Then
            If d->vertical Then
                If w->h > 0 Then
                    d->value = ((my - w->ay) * d->max_val) \ w->h
                End If
            ElseIf w->w > 0 Then
                d->value = ((mx - w->ax) * d->max_val) \ w->w
            End If
        End If
    End If

    scrollbar_ClampValue d
End Sub

' -------------------------------------------------------------------------
' Lifecycle
' -------------------------------------------------------------------------

Sub scrollbar_Destroy(ByVal w As Widget Ptr)
    Delete Cast(ScrollBarData Ptr, w->data)
End Sub

' end of scrollbar.bas

/'
    Project: omaGUI
    ---------------

    File: listbox.bas

    Purpose:
        Implement a bounded, selectable, scrolling list control.

    Responsibilities:
        - render list rows and the integrated vertical scrollbar
        - select rows through pointer or keyboard input
        - scroll through the wheel, keyboard, or scrollbar

    This file intentionally does NOT contain:
        - filesystem enumeration
        - application-specific list commands
        - global input dispatch policy
'/

#lang "fb"
#include once "src/widgets/listbox.bi"
#include once "src/widgets/scrollbar.bi"
#include once "src/backend/theme.bi"

Const LISTBOX_SCROLLBAR_WIDTH As Integer = 15
Const LISTBOX_ROW_HEIGHT As Integer = 16
Const LISTBOX_CLIP_INSET As Integer = 1
Const LISTBOX_TEXT_X_OFFSET As Integer = 4
Const LISTBOX_TEXT_Y_OFFSET As Integer = 2
Const LISTBOX_WHEEL_ROWS As Integer = 3
Const LISTBOX_KEY_UP_BIT As Integer = 1
Const LISTBOX_KEY_DOWN_BIT As Integer = 2

Private Sub listbox_ClampScroll(ByVal w As Widget Ptr)
    Dim As ListBoxData Ptr listData
    Dim As ScrollBarData Ptr scrollData
    Dim As Integer maximumScroll
    Dim As Integer visibleCount

    If w = 0 OrElse w->data = 0 Then Exit Sub

    listData = Cast(ListBoxData Ptr, w->data)
    visibleCount = w->h \ LISTBOX_ROW_HEIGHT
    If visibleCount < 1 Then visibleCount = 1
    maximumScroll = listData->item_count - visibleCount
    If maximumScroll < 0 Then maximumScroll = 0

    If listData->scroll_top < 0 Then listData->scroll_top = 0
    If listData->scroll_top > maximumScroll Then _
        listData->scroll_top = maximumScroll

    If listData->scrollbar <> 0 AndAlso _
       listData->scrollbar->data <> 0 Then
        scrollData = Cast(ScrollBarData Ptr, listData->scrollbar->data)
        scrollData->max_val = maximumScroll
        scrollData->page_size = visibleCount
        scrollData->value = listData->scroll_top
    End If
End Sub

Sub listbox_Update(ByVal w As Widget Ptr)
    Dim As ListBoxData Ptr d = w->data
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = input_MouseButtons()
    Dim As Integer wheelDelta = input_MouseWheel()
    Dim As Integer keyState
    Dim As Integer visibleCount = w->h \ LISTBOX_ROW_HEIGHT

    If visibleCount < 1 Then visibleCount = 1
    listbox_ClampScroll w

    If d->scrollbar <> 0 Then
        d->scrollbar->ax = w->ax + w->w - LISTBOX_SCROLLBAR_WIDTH
        d->scrollbar->ay = w->ay
        d->scrollbar->w = LISTBOX_SCROLLBAR_WIDTH
        d->scrollbar->h = w->h
        d->scrollbar->update(d->scrollbar)
        d->scroll_top = Cast(ScrollBarData Ptr, d->scrollbar->data)->value
    End If

    If wheelDelta <> 0 AndAlso _
       mx >= w->ax AndAlso mx < w->ax + w->w - LISTBOX_SCROLLBAR_WIDTH AndAlso _
       my >= w->ay AndAlso my < w->ay + w->h Then
        d->scroll_top -= wheelDelta * LISTBOX_WHEEL_ROWS
        listbox_ClampScroll w
    End If

    If (mb And 1) Then
        If mx >= w->ax And mx < w->ax + w->w - LISTBOX_SCROLLBAR_WIDTH And my >= w->ay And my < w->ay + w->h Then
            Dim As Integer relY = my - w->ay
            Dim As Integer idx = (relY \ LISTBOX_ROW_HEIGHT) + d->scroll_top
            If idx >= 0 And idx < d->item_count Then
                d->selected_index = idx
            End If
        End If
    End If

    If w->has_focus <> 0 Then
        If input_KeyPressed(KEY_UP) <> 0 Then keyState Or= LISTBOX_KEY_UP_BIT
        If input_KeyPressed(KEY_DOWN) <> 0 Then _
            keyState Or= LISTBOX_KEY_DOWN_BIT

        If (keyState And LISTBOX_KEY_UP_BIT) <> 0 AndAlso _
           (d->key_latch And LISTBOX_KEY_UP_BIT) = 0 Then
            If d->selected_index < 0 Then
                d->selected_index = 0
            ElseIf d->selected_index > 0 Then
                d->selected_index -= 1
            End If
        End If

        If (keyState And LISTBOX_KEY_DOWN_BIT) <> 0 AndAlso _
           (d->key_latch And LISTBOX_KEY_DOWN_BIT) = 0 Then
            If d->selected_index < 0 Then
                d->selected_index = 0
            ElseIf d->selected_index < d->item_count - 1 Then
                d->selected_index += 1
            End If
        End If

        If d->selected_index < d->scroll_top Then
            d->scroll_top = d->selected_index
        ElseIf d->selected_index >= d->scroll_top + visibleCount Then
            d->scroll_top = d->selected_index - visibleCount + 1
        End If

        d->key_latch = keyState
        listbox_ClampScroll w
    Else
        d->key_latch = 0
    End If
End Sub

Sub listbox_Render(ByVal w As Widget Ptr)
    Dim As ListBoxData Ptr d = w->data
    backend_Rect(w->ax, w->ay, w->w, w->h, theme_GetColor(GUI_COLOR_WIDGET_BG), 1)
    backend_Rect(w->ax, w->ay, w->w, w->h, theme_GetColor(GUI_COLOR_BORDER), 0)

    backend_SetClip(w->ax + LISTBOX_CLIP_INSET, w->ay + LISTBOX_CLIP_INSET, w->w - LISTBOX_SCROLLBAR_WIDTH - LISTBOX_CLIP_INSET * 2, w->h - LISTBOX_CLIP_INSET * 2)
    Dim As Integer visible_count = w->h \ LISTBOX_ROW_HEIGHT
    If visible_count < 1 Then visible_count = 1
    For i As Integer = 0 To visible_count
        Dim As Integer idx = i + d->scroll_top
        If idx >= 0 And idx < d->item_count Then
            Dim As Integer iy = w->ay + i * LISTBOX_ROW_HEIGHT
            If idx = d->selected_index Then
                backend_Rect(w->ax + LISTBOX_CLIP_INSET, iy, w->w - LISTBOX_SCROLLBAR_WIDTH - LISTBOX_CLIP_INSET * 2, LISTBOX_ROW_HEIGHT, theme_GetColor(GUI_COLOR_SELECT_BG), 1)
                backend_Print(w->ax + LISTBOX_TEXT_X_OFFSET, iy + LISTBOX_TEXT_Y_OFFSET, theme_GetColor(GUI_COLOR_SELECT_TEXT), d->items(idx))
            Else
                backend_Print(w->ax + 4, iy + 2, theme_GetColor(GUI_COLOR_TEXT), d->items(idx))
            End If
        End If
    Next
    backend_ResetClip()

    If d->scrollbar <> 0 Then
        listbox_ClampScroll w
        d->scrollbar->render(d->scrollbar)
    End If
End Sub

Sub listbox_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then
        Dim As ListBoxData Ptr d = Cast(ListBoxData Ptr, w->data)

        If d->scrollbar <> 0 Then
            If d->scrollbar->destroy <> 0 Then d->scrollbar->destroy(d->scrollbar)
            Delete d->scrollbar
            d->scrollbar = 0
        End If

        Delete d
        w->data = 0
    End If
End Sub

Function listbox_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer) As Widget Ptr
    Dim As Widget Ptr res = New Widget
    res->name = nm : res->x = x : res->y = y : res->w = w : res->h = h
    res->update = @listbox_Update : res->render = @listbox_Render : res->destroy = @listbox_Destroy
    res->visible = 1 : res->enabled = 1
    res->accepts_focus = -1
    Dim As ListBoxData Ptr d = New ListBoxData
    d->item_count = 0 : d->selected_index = -1 : d->scroll_top = 0
    d->key_latch = 0
    d->scrollbar = scrollbar_Create( _
        nm & "_sb", x + w - LISTBOX_SCROLLBAR_WIDTH, y, _
        LISTBOX_SCROLLBAR_WIDTH, h, 0, 1, -1 _
    )
    res->data = d
    Return res
End Function

Sub listbox_AddItem(ByVal w As Widget Ptr, ByVal lbl As String)
    If w = 0 OrElse w->data = 0 Then Exit Sub

    Dim As ListBoxData Ptr d = w->data
    If d->item_count < LISTBOX_MAX_ITEMS Then
        d->items(d->item_count) = lbl
        d->item_count += 1
    End If
End Sub

Sub listbox_Clear(ByVal w As Widget Ptr)
    If w = 0 OrElse w->data = 0 Then Exit Sub

    Dim As ListBoxData Ptr d = w->data
    d->item_count = 0 : d->selected_index = -1 : d->scroll_top = 0
    d->key_latch = 0
    listbox_ClampScroll w
End Sub


Function listbox_GetSelectedIndex(ByVal w As Widget Ptr) As Integer
    If w = 0 OrElse w->data = 0 Then Return -1
    Return Cast(ListBoxData Ptr, w->data)->selected_index
End Function


Function listbox_GetSelectedItem(ByVal w As Widget Ptr) As String
    Dim As ListBoxData Ptr listData

    If w = 0 OrElse w->data = 0 Then Return ""

    listData = Cast(ListBoxData Ptr, w->data)
    If listData->selected_index < 0 OrElse _
       listData->selected_index >= listData->item_count Then
        Return ""
    End If

    Return listData->items(listData->selected_index)
End Function

/' end of listbox.bas '/

/'
    Project: omaGUI
    ---------------

    File: subwindow.bas

    Purpose:
        Implement a movable, ordered, closable child window.

    Responsibilities:
        - render a title bar and optional close control
        - move the window while retaining its parent-relative coordinates
        - keep the window inside its parent client area or GUI viewport
        - notify the owning application when close is requested

    This file intentionally does NOT contain:
        - registry ordering and input dispatch
        - recursive child destruction
        - platform-native window management
'/

#lang "fb"
#include once "src/widgets/subwindow.bi"
#include once "src/backend/theme.bi"

Const SUBWINDOW_TITLEBAR_HEIGHT As Integer = 20
Const SUBWINDOW_TITLE_FILL_HEIGHT As Integer = 18
Const SUBWINDOW_TITLE_TEXT_X_OFFSET As Integer = 5
Const SUBWINDOW_TITLE_TEXT_Y_OFFSET As Integer = 4
Const SUBWINDOW_CLOSE_SIZE As Integer = 14
Const SUBWINDOW_CLOSE_RIGHT_INSET As Integer = 4
Const SUBWINDOW_CLOSE_TOP_INSET As Integer = 3
Const SUBWINDOW_CLIENT_LEFT_INSET As Integer = 1
Const SUBWINDOW_CLIENT_RIGHT_INSET As Integer = 1
Const SUBWINDOW_CLIENT_BOTTOM_INSET As Integer = 1

Private Function subwindow_PointInCloseButton( _
    ByVal w As Widget Ptr, _
    ByVal pointerX As Integer, _
    ByVal pointerY As Integer _
) As Integer
    Dim As Integer closeX
    Dim As Integer closeY

    If w = 0 Then Return 0

    closeX = w->ax + w->w - SUBWINDOW_CLOSE_RIGHT_INSET - _
        SUBWINDOW_CLOSE_SIZE
    closeY = w->ay + SUBWINDOW_CLOSE_TOP_INSET

    If pointerX >= closeX AndAlso _
       pointerX < closeX + SUBWINDOW_CLOSE_SIZE AndAlso _
       pointerY >= closeY AndAlso _
       pointerY < closeY + SUBWINDOW_CLOSE_SIZE Then
        Return -1
    End If

    Return 0
End Function


Private Sub subwindow_ClampPosition(ByVal w As Widget Ptr)
    Dim As Integer maximumX
    Dim As Integer maximumY
    Dim As Integer minimumX
    Dim As Integer minimumY
    Dim As Integer viewportHeight
    Dim As Integer viewportWidth

    If w = 0 Then Exit Sub

    If w->parent <> 0 Then
        minimumX = w->parent->child_clip_x
        minimumY = w->parent->child_clip_y
        maximumX = w->parent->w - w->parent->child_clip_right - w->w
        maximumY = w->parent->h - w->parent->child_clip_bottom - w->h
    Else
        gui_GetViewportSize viewportWidth, viewportHeight
        minimumX = 0
        minimumY = 0
        maximumX = viewportWidth - w->w
        maximumY = viewportHeight - w->h
    End If

    If maximumX < minimumX Then maximumX = minimumX
    If maximumY < minimumY Then maximumY = minimumY

    If w->x < minimumX Then w->x = minimumX
    If w->y < minimumY Then w->y = minimumY
    If w->x > maximumX Then w->x = maximumX
    If w->y > maximumY Then w->y = maximumY
End Sub

Sub subwindow_Update(ByVal w As Widget Ptr)
    Dim As SubWindowData Ptr d = w->data
    Dim As Integer parentAbsoluteX
    Dim As Integer parentAbsoluteY
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = input_MouseButtons()

    If (mb And 1) Then
        If d->closable <> 0 AndAlso d->close_latch = 0 AndAlso _
           subwindow_PointInCloseButton(w, mx, my) Then
            d->close_latch = -1
            d->close_requested = -1
            d->dragging = 0

            If d->close_handler <> 0 Then
                Cast(Sub(ByVal As Widget Ptr), d->close_handler)(w)
            Else
                w->visible = 0
                w->enabled = 0
            End If

            Exit Sub
        End If

        If d->dragging Then
            If w->parent <> 0 Then
                parentAbsoluteX = w->parent->ax
                parentAbsoluteY = w->parent->ay
            End If

            w->x = mx - parentAbsoluteX - d->drag_off_x
            w->y = my - parentAbsoluteY - d->drag_off_y
            subwindow_ClampPosition w
        Elseif mx >= w->ax AndAlso mx < w->ax + w->w AndAlso _
               my >= w->ay AndAlso _
               my < w->ay + SUBWINDOW_TITLEBAR_HEIGHT Then
            d->dragging = 1
            d->drag_off_x = mx - w->ax
            d->drag_off_y = my - w->ay
        End If
    Else
        d->dragging = 0
        d->close_latch = 0
    End If
End Sub

Sub subwindow_Render(ByVal w As Widget Ptr)
    Dim As SubWindowData Ptr d = w->data
    Dim As Integer closeX
    Dim As Integer closeY

    backend_Rect(w->ax, w->ay, w->w, w->h, theme_GetColor(GUI_COLOR_BORDER), 0)
    backend_Rect(w->ax + 1, w->ay + 1, w->w - 2, w->h - 2, theme_GetColor(GUI_COLOR_WINDOW_BG), 1)
    backend_Rect(w->ax + 2, w->ay + 2, w->w - 4, SUBWINDOW_TITLE_FILL_HEIGHT, theme_GetColor(GUI_COLOR_SELECT_BG), 1)
    backend_Print(w->ax + SUBWINDOW_TITLE_TEXT_X_OFFSET, w->ay + SUBWINDOW_TITLE_TEXT_Y_OFFSET, theme_GetColor(GUI_COLOR_SELECT_TEXT), d->title)

    If d->closable <> 0 Then
        closeX = w->ax + w->w - SUBWINDOW_CLOSE_RIGHT_INSET - _
            SUBWINDOW_CLOSE_SIZE
        closeY = w->ay + SUBWINDOW_CLOSE_TOP_INSET
        backend_Rect closeX, closeY, SUBWINDOW_CLOSE_SIZE, _
            SUBWINDOW_CLOSE_SIZE, current_theme.bg_face, 1
        backend_Rect closeX, closeY, SUBWINDOW_CLOSE_SIZE, _
            SUBWINDOW_CLOSE_SIZE, current_theme.win_border, 0
        backend_Line closeX + 3, closeY + 3, _
            closeX + SUBWINDOW_CLOSE_SIZE - 4, _
            closeY + SUBWINDOW_CLOSE_SIZE - 4, current_theme.text_main
        backend_Line closeX + SUBWINDOW_CLOSE_SIZE - 4, closeY + 3, _
            closeX + 3, closeY + SUBWINDOW_CLOSE_SIZE - 4, _
            current_theme.text_main
    End If
End Sub

Sub subwindow_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then Delete Cast(SubWindowData Ptr, w->data)
End Sub

Function subwindow_Create( _
    ByVal nm As String, ByVal titl As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal closable As Integer _
) As Widget Ptr
    Dim As Widget Ptr res = New Widget
    res->name = nm : res->x = x : res->y = y : res->w = w : res->h = h
    res->update = @subwindow_Update : res->render = @subwindow_Render : res->destroy = @subwindow_Destroy
    res->visible = 1 : res->enabled = 1
    res->is_window = -1
    res->clip_children = -1
    res->child_clip_x = SUBWINDOW_CLIENT_LEFT_INSET
    res->child_clip_y = SUBWINDOW_TITLEBAR_HEIGHT
    res->child_clip_right = SUBWINDOW_CLIENT_RIGHT_INSET
    res->child_clip_bottom = SUBWINDOW_CLIENT_BOTTOM_INSET
    Dim As SubWindowData Ptr d = New SubWindowData
    d->title = titl
    d->dragging = 0
    d->closable = IIf(closable <> 0, -1, 0)
    d->close_requested = 0
    d->close_latch = 0
    d->close_handler = 0
    res->data = d : Return res
End Function


Sub subwindow_SetCloseHandler( _
    ByVal w As Widget Ptr, ByVal closeHandler As Any Ptr _
)
    If w = 0 OrElse w->data = 0 Then Exit Sub
    Cast(SubWindowData Ptr, w->data)->close_handler = closeHandler
End Sub


Sub subwindow_SetClosable(ByVal w As Widget Ptr, ByVal closable As Integer)
    If w = 0 OrElse w->data = 0 Then Exit Sub
    Cast(SubWindowData Ptr, w->data)->closable = _
        IIf(closable <> 0, -1, 0)
End Sub


Function subwindow_CloseRequested(ByVal w As Widget Ptr) As Integer
    If w = 0 OrElse w->data = 0 Then Return 0
    Return Cast(SubWindowData Ptr, w->data)->close_requested
End Function


Sub subwindow_Reopen(ByVal w As Widget Ptr)
    Dim As SubWindowData Ptr windowData

    If w = 0 OrElse w->data = 0 Then Exit Sub

    windowData = Cast(SubWindowData Ptr, w->data)
    windowData->close_requested = 0
    windowData->close_latch = 0
    windowData->dragging = 0
    w->visible = -1
    w->enabled = -1
    gui_BringToFront w
End Sub

/' end of subwindow.bas '/

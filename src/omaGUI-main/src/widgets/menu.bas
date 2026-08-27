/'
    Project: omaGUI
    ---------------
    File: menu.bas
    Purpose: Popup menu widget implementation.
'/
#lang "fb"

#include once "src/widgets/menu.bi"
#include once "src/widgets/widgets.bi"

Const MENU_DEFAULT_WIDTH As Integer = 100
Const MENU_ITEM_HEIGHT As Integer = 20
Const MENU_SELECTION_INSET As Integer = 2
Const MENU_TEXT_INSET As Integer = 5

' -------------------------------------------------------------------------
' Construction
' -------------------------------------------------------------------------

Function menu_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As MenuData Ptr d = New MenuData
    wgt->name = nm : wgt->x = x : wgt->y = y : wgt->w = MENU_DEFAULT_WIDTH : wgt->h = 0
    wgt->visible = 0 : wgt->enabled = 1
    wgt->pointer_global = -1
    wgt->render = @menu_Render : wgt->update = @menu_Update : wgt->destroy = @menu_Destroy
    d->count = 0 : d->selected = -1
    d->selection_handler = 0 : d->selection_context = 0
    wgt->data = d
    Return wgt
End Function

' -------------------------------------------------------------------------
' Menu Items
' -------------------------------------------------------------------------

Sub menu_AddItem(ByVal m As Widget Ptr, ByVal txt As String, ByVal cb As Sub(ByVal As Integer))
    Dim As MenuData Ptr d = m->data
    If d->count >= MENU_MAX_ITEMS Then Exit Sub
    d->items(d->count) = txt
    d->callbacks(d->count) = cb
    d->count += 1

    ' Auto-size
    m->h = d->count * 20 + 4
    Dim As Integer tw = backend_GetTextWidth(txt) + 20
    If tw > m->w Then m->w = tw
End Sub


Sub menu_ClearItems(ByVal m As Widget Ptr)
    Dim As MenuData Ptr d

    If m = 0 OrElse m->data = 0 Then Exit Sub
    d = Cast(MenuData Ptr, m->data)

    For itemIndex As Integer = 0 To MENU_MAX_ITEMS - 1
        d->items(itemIndex) = ""
        d->callbacks(itemIndex) = 0
    Next itemIndex

    d->count = 0
    d->selected = -1
    m->h = 0
End Sub


Sub menu_SetSelectionHandler( _
    ByVal m As Widget Ptr, _
    ByVal selection_handler As Any Ptr, ByVal selection_context As Any Ptr _
)
    Dim As MenuData Ptr d

    If m = 0 OrElse m->data = 0 Then Exit Sub
    d = Cast(MenuData Ptr, m->data)
    d->selection_handler = selection_handler
    d->selection_context = selection_context
End Sub

' -------------------------------------------------------------------------
' Rendering
' -------------------------------------------------------------------------

Sub menu_Render(ByVal w As Widget Ptr)
    Dim As MenuData Ptr d = w->data
    backend_Rect(w->ax, w->ay, w->w, w->h, current_theme.win_border, 0)
    backend_Rect(w->ax + 1, w->ay + 1, w->w - 2, w->h - 2, current_theme.bg_face, 1)

    For i As Integer = 0 To d->count - 1
        If d->selected = i Then
            backend_Rect(w->ax + MENU_SELECTION_INSET, w->ay + MENU_SELECTION_INSET + i * MENU_ITEM_HEIGHT, w->w - MENU_SELECTION_INSET * 2, MENU_ITEM_HEIGHT, current_theme.bg_select, 1)
            backend_Print(w->ax + MENU_TEXT_INSET, w->ay + MENU_TEXT_INSET + i * MENU_ITEM_HEIGHT, current_theme.text_select, d->items(i))
        Else
            backend_Print(w->ax + MENU_TEXT_INSET, w->ay + MENU_TEXT_INSET + i * MENU_ITEM_HEIGHT, current_theme.text_main, d->items(i))
        End If
    Next
End Sub

' -------------------------------------------------------------------------
' Processing
' -------------------------------------------------------------------------

Sub menu_Update(ByVal w As Widget Ptr)
    Dim As MenuData Ptr d = w->data
    Dim As Integer mx = input_MouseX()
    Dim As Integer my = input_MouseY()
    Dim As Integer mb = input_MouseButtons()

    If mx >= w->ax And mx < w->ax + w->w And my >= w->ay And my < w->ay + w->h Then
        d->selected = (my - w->ay - 2) \ 20
        If mb And 1 Then
            If d->selected >= 0 And d->selected < d->count Then
                If d->selection_handler <> 0 Then
                    Cast( _
                        Sub(ByVal As Any Ptr, ByVal As Integer), _
                        d->selection_handler _
                    )(d->selection_context, d->selected)
                ElseIf d->callbacks(d->selected) <> 0 Then
                    d->callbacks(d->selected)(d->selected)
                End If
            End If
            w->visible = 0
        End If
    Else
        d->selected = -1
        If mb And 1 Then w->visible = 0
    End If
End Sub

' -------------------------------------------------------------------------
' Lifecycle
' -------------------------------------------------------------------------

Sub menu_Destroy(ByVal w As Widget Ptr)
    Delete Cast(MenuData Ptr, w->data)
End Sub

' end of menu.bas

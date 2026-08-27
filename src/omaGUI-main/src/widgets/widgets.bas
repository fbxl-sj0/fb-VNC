/'
    Project: omaGUI
    ---------------

    File: widgets.bas

    Purpose:
        Manage widget registration, hierarchy, input, drawing, and layout.

    Responsibilities:
        - own the widget registry and modal root
        - resolve parent-relative coordinates
        - route pointer input to the topmost eligible widget
        - maintain movable-window stacking and keyboard focus
        - clip child rendering and hit testing to parent client areas
        - react to drawable-area changes through reusable anchor constraints
        - dispatch widget updates and rendering in registry order

    This file intentionally does NOT contain:
        - individual widget behavior or appearance
        - platform window creation and event handling
        - application-specific layout rules
'/
#lang "fb"
#include once "src/widgets/widgets.bi"
#include once "src/widgets/radiobox.bi"

' -------------------------------------------------------------------------
' Global State
' -------------------------------------------------------------------------

Dim Shared As Widget Ptr widget_list_head = 0
Dim Shared As Widget Ptr widget_list_tail = 0
Dim Shared As Widget Ptr widget_modal_root = 0
Dim Shared As Widget Ptr widget_pointer_capture = 0
Dim Shared As Widget Ptr widget_focus = 0
Dim Shared As Widget Ptr widget_pending_front = 0
Dim Shared As Integer gui_UpdateInProgress
Dim Shared As Integer gui_ViewportWidth
Dim Shared As Integer gui_ViewportHeight
Dim Shared As UInteger gui_LayoutGeneration

Const GUI_LAYOUT_PARENT_GUARD As Integer = 64
Const GUI_LAYOUT_MINIMUM_SIZE As Integer = 1

' -------------------------------------------------------------------------
' Registry Management
' -------------------------------------------------------------------------

Sub gui_Init()
    widget_list_head = 0
    widget_list_tail = 0
    widget_modal_root = 0
    widget_pointer_capture = 0
    widget_focus = 0
    widget_pending_front = 0
    gui_UpdateInProgress = 0
    gui_LayoutGeneration = 0
    backend_GetSize gui_ViewportWidth, gui_ViewportHeight

    If gui_ViewportWidth < GUI_LAYOUT_MINIMUM_SIZE Then _
        gui_ViewportWidth = GUI_LAYOUT_MINIMUM_SIZE
    If gui_ViewportHeight < GUI_LAYOUT_MINIMUM_SIZE Then _
        gui_ViewportHeight = GUI_LAYOUT_MINIMUM_SIZE
End Sub


Private Function gui_IsNameTaken(ByVal widgetName As String) As Integer
    Dim As Widget Ptr current = widget_list_head

    While current <> 0
        If LCase(current->name) = LCase(widgetName) Then Return -1
        current = current->next_widget
    Wend

    Return 0
End Function


Private Sub gui_AppendWidget(ByVal w As Widget Ptr)
    If w = 0 Then Exit Sub

    w->next_widget = 0
    If widget_list_head = 0 Then
        widget_list_head = w
        widget_list_tail = w
    Else
        widget_list_tail->next_widget = w
        widget_list_tail = w
    End If
End Sub


Sub gui_AddWidget(ByVal w As Widget Ptr)
    Dim As String baseName
    Dim As Integer suffix

    If w = 0 Then Exit Sub

    /'
        Names are public lookup keys. Preserve the original manager contract
        by suffixing duplicates instead of making gui_FindWidget ambiguous.
    '/
    If gui_IsNameTaken(w->name) Then
        baseName = w->name
        suffix = 1

        While gui_IsNameTaken(baseName & "_" & suffix)
            suffix += 1
        Wend

        w->name = baseName & "_" & suffix
    End If

    gui_AppendWidget w
End Sub


Sub gui_AddGeneratedWidget(ByVal w As Widget Ptr)
    /'
        Generated importers already allocate monotonic names. Their fast path
        deliberately skips the duplicate-name scan on very large HMI pages.
    '/
    gui_AppendWidget w
End Sub


Sub gui_SetParent(ByVal child As Widget Ptr, ByVal parent As Widget Ptr)
    Dim As Widget Ptr current
    Dim As Integer parentDepth

    If child = 0 Then Exit Sub
    If child = parent Then Exit Sub

    /'
        A parent cycle would make coordinate resolution and recursive removal
        unsafe. Walk the proposed chain before accepting it and reject chains
        that are cyclic or already exceed the supported hierarchy depth.
    '/
    current = parent
    parentDepth = 0

    While current <> 0 AndAlso parentDepth < GUI_LAYOUT_PARENT_GUARD
        If current = child Then Exit Sub
        current = current->parent
        parentDepth += 1
    Wend

    If current <> 0 Then Exit Sub
    child->parent = parent
End Sub


Private Function gui_IsWithinTree( _
    ByVal w As Widget Ptr, ByVal root As Widget Ptr _
) As Integer
    Dim As Widget Ptr current = w
    Dim As Integer parentDepth

    If root = 0 Then Return 1

    While current <> 0 AndAlso parentDepth < GUI_LAYOUT_PARENT_GUARD
        If current = root Then Return 1
        current = current->parent
        parentDepth += 1
    Wend

    Return 0
End Function


Private Function gui_FindOwningWindow( _
    ByVal w As Widget Ptr _
) As Widget Ptr
    Dim As Widget Ptr current = w
    Dim As Integer parentDepth

    While current <> 0 AndAlso parentDepth < GUI_LAYOUT_PARENT_GUARD
        If current->is_window <> 0 Then Return current
        current = current->parent
        parentDepth += 1
    Wend

    Return 0
End Function


Private Function gui_FindStackRoot(ByVal w As Widget Ptr) As Widget Ptr
    Dim As Widget Ptr current
    Dim As Widget Ptr windowRoot
    Dim As Integer parentDepth

    If w = 0 Then Return 0

    windowRoot = gui_FindOwningWindow(w)
    If windowRoot <> 0 Then Return windowRoot

    current = w
    While current->parent <> 0 AndAlso parentDepth < GUI_LAYOUT_PARENT_GUARD
        current = current->parent
        parentDepth += 1
    Wend

    If parentDepth >= GUI_LAYOUT_PARENT_GUARD Then Return 0
    Return current
End Function


Sub gui_BringToFront(ByVal w As Widget Ptr)
    Dim As Widget Ptr current
    Dim As Widget Ptr keepHead
    Dim As Widget Ptr keepTail
    Dim As Widget Ptr moveHead
    Dim As Widget Ptr moveTail
    Dim As Widget Ptr nextWidget
    Dim As Widget Ptr stackRoot

    stackRoot = gui_FindStackRoot(w)
    If stackRoot = 0 Then Exit Sub

    /'
        A callback can request foreground activation while the manager is
        traversing the registry. Defer that mutation until the frame ends so
        no widget is skipped or updated twice through changed next pointers.
    '/
    If gui_UpdateInProgress <> 0 Then
        widget_pending_front = stackRoot
        Exit Sub
    End If

    /'
        The registry is also the paint order. Rebuild it as two stable lists,
        retaining the relative order of both the unaffected widgets and every
        member of the selected window tree. Appending the selected tree makes
        it the foreground window without invalidating widget pointers.
    '/
    current = widget_list_head

    While current <> 0
        nextWidget = current->next_widget
        current->next_widget = 0

        If current = stackRoot OrElse _
           gui_IsWithinTree(current, stackRoot) Then
            If moveHead = 0 Then
                moveHead = current
                moveTail = current
            Else
                moveTail->next_widget = current
                moveTail = current
            End If
        Else
            If keepHead = 0 Then
                keepHead = current
                keepTail = current
            Else
                keepTail->next_widget = current
                keepTail = current
            End If
        End If

        current = nextWidget
    Wend

    If moveHead = 0 Then Exit Sub

    If keepHead = 0 Then
        widget_list_head = moveHead
    Else
        widget_list_head = keepHead
        keepTail->next_widget = moveHead
    End If

    widget_list_tail = moveTail
End Sub


Sub gui_SetFocus(ByVal w As Widget Ptr)
    If w <> 0 AndAlso w->accepts_focus = 0 Then w = 0
    If widget_focus = w Then Exit Sub

    If widget_focus <> 0 Then widget_focus->has_focus = 0
    widget_focus = w
    If widget_focus <> 0 Then widget_focus->has_focus = -1
End Sub


Function gui_GetFocus() As Widget Ptr
    Return widget_focus
End Function


Sub gui_SetModalRoot(ByVal root As Widget Ptr)
    widget_modal_root = root
End Sub


Sub gui_ClearModalRoot(ByVal root As Widget Ptr)
    If root = 0 OrElse widget_modal_root = root Then
        widget_modal_root = 0
    End If
End Sub


Function gui_IsModalOpen() As Integer
    If widget_modal_root <> 0 Then Return 1
    Return 0
End Function


' -------------------------------------------------------------------------
' Reactive layout
' -------------------------------------------------------------------------

Private Sub gui_AdvanceLayoutGeneration()
    If gui_LayoutGeneration >= &H7FFFFFF0 Then
        gui_LayoutGeneration = 1

        Dim As Widget Ptr current = widget_list_head
        While current <> 0
            current->layout_generation = 0
            current = current->next_widget
        Wend
    Else
        gui_LayoutGeneration += 1
    End If
End Sub


Private Sub gui_ApplyWidgetAnchors( _
    ByVal w As Widget Ptr, _
    ByVal parentDepth As Integer _
)

    Dim As Integer containerWidth
    Dim As Integer containerHeight
    Dim As Integer deltaWidth
    Dim As Integer deltaHeight
    Dim As UInteger horizontalAnchors
    Dim As UInteger verticalAnchors

    If w = 0 OrElse w->layout_generation = gui_LayoutGeneration Then Exit Sub

    If parentDepth >= GUI_LAYOUT_PARENT_GUARD Then
        w->visible = 0
        w->enabled = 0
        w->layout_generation = gui_LayoutGeneration
        Exit Sub
    End If

    If w->parent <> 0 Then
        gui_ApplyWidgetAnchors w->parent, parentDepth + 1
        containerWidth = w->parent->w
        containerHeight = w->parent->h
    Else
        containerWidth = gui_ViewportWidth
        containerHeight = gui_ViewportHeight
    End If

    If w->layout_initialized <> 0 Then
        deltaWidth = containerWidth - w->layout_container_w
        deltaHeight = containerHeight - w->layout_container_h
        horizontalAnchors = w->anchor_flags And _
            (GUI_ANCHOR_LEFT Or GUI_ANCHOR_RIGHT)
        verticalAnchors = w->anchor_flags And _
            (GUI_ANCHOR_TOP Or GUI_ANCHOR_BOTTOM)

        Select Case horizontalAnchors
        Case GUI_ANCHOR_LEFT Or GUI_ANCHOR_RIGHT
            w->x = w->layout_base_x
            w->w = w->layout_base_w + deltaWidth
        Case GUI_ANCHOR_RIGHT
            w->x = w->layout_base_x + deltaWidth
            w->w = w->layout_base_w
        Case GUI_ANCHOR_LEFT
            w->x = w->layout_base_x
            w->w = w->layout_base_w
        Case Else
            w->x = w->layout_base_x + deltaWidth \ 2
            w->w = w->layout_base_w
        End Select

        Select Case verticalAnchors
        Case GUI_ANCHOR_TOP Or GUI_ANCHOR_BOTTOM
            w->y = w->layout_base_y
            w->h = w->layout_base_h + deltaHeight
        Case GUI_ANCHOR_BOTTOM
            w->y = w->layout_base_y + deltaHeight
            w->h = w->layout_base_h
        Case GUI_ANCHOR_TOP
            w->y = w->layout_base_y
            w->h = w->layout_base_h
        Case Else
            w->y = w->layout_base_y + deltaHeight \ 2
            w->h = w->layout_base_h
        End Select

        If w->w < GUI_LAYOUT_MINIMUM_SIZE Then w->w = GUI_LAYOUT_MINIMUM_SIZE
        If w->h < GUI_LAYOUT_MINIMUM_SIZE Then w->h = GUI_LAYOUT_MINIMUM_SIZE
    End If

    w->layout_generation = gui_LayoutGeneration

End Sub


Private Sub gui_ApplyReactiveLayout()

    gui_AdvanceLayoutGeneration

    Dim As Widget Ptr current = widget_list_head
    While current <> 0
        gui_ApplyWidgetAnchors current, 0
        current = current->next_widget
    Wend

End Sub


Sub gui_SetViewportSize(ByVal w As Integer, ByVal h As Integer)

    If w < GUI_LAYOUT_MINIMUM_SIZE Then w = GUI_LAYOUT_MINIMUM_SIZE
    If h < GUI_LAYOUT_MINIMUM_SIZE Then h = GUI_LAYOUT_MINIMUM_SIZE

    If w = gui_ViewportWidth AndAlso h = gui_ViewportHeight Then Exit Sub

    gui_ViewportWidth = w
    gui_ViewportHeight = h
    gui_ApplyReactiveLayout

End Sub


Sub gui_GetViewportSize(ByRef w As Integer, ByRef h As Integer)
    w = gui_ViewportWidth
    h = gui_ViewportHeight
End Sub


Sub gui_SetAnchors(ByVal w As Widget Ptr, ByVal anchorFlags As UInteger)

    If w = 0 Then Exit Sub

    w->anchor_flags = anchorFlags And GUI_ANCHOR_ALL
    w->layout_initialized = -1
    w->layout_base_x = w->x
    w->layout_base_y = w->y
    w->layout_base_w = w->w
    w->layout_base_h = w->h

    If w->parent <> 0 Then
        w->layout_container_w = w->parent->w
        w->layout_container_h = w->parent->h
    Else
        w->layout_container_w = gui_ViewportWidth
        w->layout_container_h = gui_ViewportHeight
    End If

    gui_ApplyReactiveLayout

End Sub


Sub gui_ResetAnchors(ByVal w As Widget Ptr)
    If w = 0 Then Exit Sub

    w->anchor_flags = GUI_ANCHOR_NONE
    w->layout_initialized = 0
    w->layout_generation = 0
End Sub


Private Sub gui_RebaseWidgetLayout(ByVal w As Widget Ptr)
    If w = 0 OrElse w->layout_initialized = 0 Then Exit Sub

    w->layout_base_x = w->x
    w->layout_base_y = w->y
    w->layout_base_w = w->w
    w->layout_base_h = w->h

    If w->parent <> 0 Then
        w->layout_container_w = w->parent->w
        w->layout_container_h = w->parent->h
    Else
        w->layout_container_w = gui_ViewportWidth
        w->layout_container_h = gui_ViewportHeight
    End If
End Sub


Private Function gui_PointWithinWidget( _
    ByVal w As Widget Ptr, _
    ByVal pointerX As Integer, _
    ByVal pointerY As Integer _
) As Integer
    Dim As Integer bottomEdge
    Dim As Integer leftEdge
    Dim As Integer rightEdge
    Dim As Integer topEdge

    If w = 0 Then Return 0

    leftEdge = w->ax
    topEdge = w->ay
    rightEdge = w->ax + w->w
    bottomEdge = w->ay + w->h

    If rightEdge < leftEdge Then Swap rightEdge, leftEdge
    If bottomEdge < topEdge Then Swap bottomEdge, topEdge

    If pointerX >= leftEdge AndAlso pointerX < rightEdge AndAlso _
       pointerY >= topEdge AndAlso pointerY < bottomEdge Then
        Return -1
    End If

    Return 0
End Function


Private Function gui_PointWithinParentClients( _
    ByVal w As Widget Ptr, _
    ByVal pointerX As Integer, _
    ByVal pointerY As Integer _
) As Integer
    Dim As Integer clipHeight
    Dim As Integer clipWidth
    Dim As Integer clipX
    Dim As Integer clipY
    Dim As Widget Ptr parent
    Dim As Integer parentDepth

    If w = 0 Then Return 0

    parent = w->parent
    While parent <> 0 AndAlso parentDepth < GUI_LAYOUT_PARENT_GUARD
        If parent->clip_children <> 0 Then
            clipX = parent->ax + parent->child_clip_x
            clipY = parent->ay + parent->child_clip_y
            clipWidth = parent->w - parent->child_clip_x - _
                parent->child_clip_right
            clipHeight = parent->h - parent->child_clip_y - _
                parent->child_clip_bottom

            If pointerX < clipX OrElse pointerX >= clipX + clipWidth OrElse _
               pointerY < clipY OrElse pointerY >= clipY + clipHeight Then
                Return 0
            End If
        End If

        parent = parent->parent
        parentDepth += 1
    Wend

    If parent <> 0 Then Return 0
    Return -1
End Function


Private Function gui_FindTopmostWindowAt( _
    ByVal pointerX As Integer, _
    ByVal pointerY As Integer _
) As Widget Ptr
    Dim As Widget Ptr current = widget_list_head
    Dim As Widget Ptr result

    While current <> 0
        If current->is_window <> 0 AndAlso current->evis <> 0 AndAlso _
           current->een <> 0 AndAlso _
           gui_IsWithinTree(current, widget_modal_root) <> 0 AndAlso _
           gui_PointWithinWidget(current, pointerX, pointerY) <> 0 AndAlso _
           gui_PointWithinParentClients( _
               current, pointerX, pointerY _
           ) <> 0 Then
            result = current
        End If

        current = current->next_widget
    Wend

    Return result
End Function


Private Function gui_FindTopmostPointerWidget( _
    ByVal pointerX As Integer, _
    ByVal pointerY As Integer _
) As Widget Ptr
    Dim As Widget Ptr current = widget_list_head
    Dim As Widget Ptr owningWindow
    Dim As Widget Ptr result
    Dim As Widget Ptr topWindow

    topWindow = gui_FindTopmostWindowAt(pointerX, pointerY)

    While current <> 0
        If current->update <> 0 AndAlso current->evis <> 0 AndAlso _
           current->een <> 0 AndAlso _
           gui_IsWithinTree(current, widget_modal_root) <> 0 Then
            owningWindow = gui_FindOwningWindow(current)

            If (topWindow = 0 AndAlso owningWindow = 0) OrElse _
               owningWindow = topWindow OrElse current->pointer_global <> 0 Then
                If current->pointer_global <> 0 OrElse _
                   (gui_PointWithinWidget( _
                       current, pointerX, pointerY _
                   ) <> 0 AndAlso _
                   gui_PointWithinParentClients( _
                       current, pointerX, pointerY _
                   ) <> 0) Then
                    result = current
                End If
            End If
        End If

        current = current->next_widget
    Wend

    Return result
End Function


Private Function gui_GetWidgetRenderClip( _
    ByVal w As Widget Ptr, _
    ByRef clipX As Integer, _
    ByRef clipY As Integer, _
    ByRef clipWidth As Integer, _
    ByRef clipHeight As Integer _
) As Integer
    Dim As Integer clipBottom
    Dim As Integer clipRight
    Dim As Integer parentBottom
    Dim As Integer parentLeft
    Dim As Integer parentRight
    Dim As Integer parentTop
    Dim As Widget Ptr parent
    Dim As Integer parentDepth

    backend_GetSize clipWidth, clipHeight
    clipX = 0
    clipY = 0

    If clipWidth <= 0 OrElse clipHeight <= 0 Then Return 0
    If w = 0 Then Return 0

    clipRight = clipWidth
    clipBottom = clipHeight

    parent = w->parent
    While parent <> 0 AndAlso parentDepth < GUI_LAYOUT_PARENT_GUARD
        If parent->clip_children <> 0 Then
            parentLeft = parent->ax + parent->child_clip_x
            parentTop = parent->ay + parent->child_clip_y
            parentRight = parent->ax + parent->w - _
                parent->child_clip_right
            parentBottom = parent->ay + parent->h - _
                parent->child_clip_bottom

            If clipX < parentLeft Then clipX = parentLeft
            If clipY < parentTop Then clipY = parentTop
            If clipRight > parentRight Then clipRight = parentRight
            If clipBottom > parentBottom Then clipBottom = parentBottom
        End If

        parent = parent->parent
        parentDepth += 1
    Wend

    clipWidth = clipRight - clipX
    clipHeight = clipBottom - clipY

    If parent <> 0 OrElse clipWidth <= 0 OrElse clipHeight <= 0 Then Return 0
    Return -1
End Function


Private Sub gui_ResolveLayout()
    Dim As Widget Ptr current = widget_list_head
    Dim As Integer guard

    While current <> 0
        guard = 0

        If current->parent = 0 Then
            current->ax = current->x
            current->ay = current->y
            current->evis = current->visible
            current->een = current->enabled
        Else
            /'
                Parents are added before their child controls in the editor and
                generated dialogs.  The guard keeps malformed parent cycles
                from turning a UI update into an infinite loop.
            '/
            current->ax = current->x
            current->ay = current->y
            current->evis = current->visible
            current->een = current->enabled

            Dim As Widget Ptr parent = current->parent
            While parent <> 0 AndAlso guard < GUI_LAYOUT_PARENT_GUARD
                current->ax += parent->x
                current->ay += parent->y
                current->evis = current->evis And parent->visible
                current->een = current->een And parent->enabled
                parent = parent->parent
                guard += 1
            Wend

            If guard >= GUI_LAYOUT_PARENT_GUARD Then
                current->evis = 0
                current->een = 0
            End If
        End If

        current = current->next_widget
    Wend
End Sub


Private Sub gui_DeleteWidget(ByVal target As Widget Ptr)
    Dim As Widget Ptr current
    Dim As Widget Ptr previous

    If target = 0 Then Exit Sub

    current = widget_list_head
    previous = 0

    While current <> 0
        If current = target Then
            If previous = 0 Then
                widget_list_head = current->next_widget
            Else
                previous->next_widget = current->next_widget
            End If

            If widget_list_tail = current Then widget_list_tail = previous

            If current->destroy <> 0 Then current->destroy(current)
            Delete current
            Exit Sub
        End If

        previous = current
        current = current->next_widget
    Wend
End Sub


Private Sub gui_DeleteWidgetTree(ByVal target As Widget Ptr)
    Dim As Widget Ptr current
    Dim As Integer removedChild

    If target = 0 Then Exit Sub

    If widget_focus <> 0 AndAlso _
       gui_IsWithinTree(widget_focus, target) Then
        gui_SetFocus 0
    End If

    If widget_pointer_capture <> 0 AndAlso _
       gui_IsWithinTree(widget_pointer_capture, target) Then
        widget_pointer_capture = 0
    End If

    If widget_pending_front <> 0 AndAlso _
       gui_IsWithinTree(widget_pending_front, target) Then
        widget_pending_front = 0
    End If

    Do
        removedChild = 0
        current = widget_list_head

        While current <> 0
            If current->parent = target Then
                gui_DeleteWidgetTree current
                removedChild = 1
                Exit While
            End If

            current = current->next_widget
        Wend
    Loop While removedChild <> 0

    gui_DeleteWidget target
End Sub

Sub gui_ResetForTest()
    While widget_list_head <> 0
        gui_DeleteWidgetTree widget_list_head
    Wend

    widget_modal_root = 0
    widget_list_tail = 0
    widget_pointer_capture = 0
    widget_pending_front = 0
    gui_UpdateInProgress = 0
    gui_SetFocus 0
End Sub

Sub gui_RemoveWidget(ByVal nm As String)
    Dim As Widget Ptr curr = widget_list_head
    While curr <> 0
        If LCase(curr->name) = LCase(nm) Then
            gui_ClearModalRoot curr
            gui_DeleteWidgetTree curr
            Exit Sub
        End If
        curr = curr->next_widget
    Wend
End Sub

Function gui_FindWidget(ByVal nm As String) As Widget Ptr
    Dim As Widget Ptr curr = widget_list_head
    While curr <> 0
        If LCase(curr->name) = LCase(nm) Then Return curr : End If
        curr = curr->next_widget
    Wend
    Return 0
End Function

Sub gui_DeselectRadioGroup(ByVal group_id As Integer, ByVal caller As Widget Ptr)
    Dim As Widget Ptr curr = widget_list_head
    While curr <> 0
        If curr <> caller And curr->render = @radiobox_Render Then
            Dim As RadioBoxData Ptr d = curr->data
            If d->group_id = group_id Then d->selected = 0
        End If
        curr = curr->next_widget
    Wend
End Sub

' -------------------------------------------------------------------------
' Processing Loops
' -------------------------------------------------------------------------

Sub gui_UpdateAll()
    Dim As Integer allowKeyboard
    Dim As Integer allowPointer
    Dim As Integer mouseButtons
    Dim As Integer mouseX
    Dim As Integer mouseY
    Dim As Widget Ptr pointerTarget
    Dim As Widget Ptr releasedCapture
    Dim As Widget Ptr topWindow
    Dim As Integer viewportWidth
    Dim As Integer viewportHeight
    Dim As Integer previousX
    Dim As Integer previousY
    Dim As Integer previousWidth
    Dim As Integer previousHeight
    Dim As Integer previousEnabled
    Dim As Integer previousVisible

    input_Update()
    backend_GetSize viewportWidth, viewportHeight
    gui_SetViewportSize viewportWidth, viewportHeight

    gui_ResolveLayout()

    /'
        Read the unmasked frame input once. Each widget update below receives
        a dispatch mask, which prevents overlapping controls from observing
        the same pointer transition while preserving ordinary update calls for
        animation and non-input state.
    '/
    input_SetDispatchMask -1, -1
    mouseX = input_MouseX()
    mouseY = input_MouseY()
    mouseButtons = input_MouseButtons()

    If widget_pointer_capture <> 0 Then
        pointerTarget = widget_pointer_capture

        If mouseButtons = 0 Then
            releasedCapture = widget_pointer_capture
            widget_pointer_capture = 0
        End If
    Else
        pointerTarget = gui_FindTopmostPointerWidget(mouseX, mouseY)

        If mouseButtons <> 0 AndAlso pointerTarget <> 0 Then
            topWindow = gui_FindOwningWindow(pointerTarget)

            If topWindow <> 0 Then
                gui_BringToFront topWindow
                gui_ResolveLayout
                pointerTarget = gui_FindTopmostPointerWidget(mouseX, mouseY)
            End If

            widget_pointer_capture = pointerTarget

            If pointerTarget->accepts_focus <> 0 Then
                gui_SetFocus pointerTarget
            Else
                gui_SetFocus 0
            End If
        End If
    End If

    If releasedCapture <> 0 Then pointerTarget = releasedCapture

    Dim As Widget Ptr curr = widget_list_head
    gui_UpdateInProgress = -1

    While curr <> 0
        curr->updated_this_frame = 0
        previousX = curr->x
        previousY = curr->y
        previousWidth = curr->w
        previousHeight = curr->h
        previousVisible = curr->visible
        previousEnabled = curr->enabled

        If curr->evis AndAlso curr->een AndAlso _
           gui_IsWithinTree(curr, widget_modal_root) Then
            allowPointer = IIf(curr = pointerTarget, -1, 0)
            allowKeyboard = IIf(curr = widget_focus, -1, 0)
            input_SetDispatchMask allowPointer, allowKeyboard

            If curr->update <> 0 Then curr->update(curr)
            curr->updated_this_frame = 1
        End If

        /'
            Most controls do not change their rectangle during update. Only
            resolve the complete hierarchy again when a movable or resizable
            parent actually changed, preserving correct child input without
            turning every frame into a quadratic registry walk.
        '/
        If curr->x <> previousX OrElse curr->y <> previousY OrElse _
           curr->w <> previousWidth OrElse curr->h <> previousHeight Then
            gui_RebaseWidgetLayout curr
            gui_ResolveLayout()
        ElseIf curr->visible <> previousVisible OrElse _
               curr->enabled <> previousEnabled Then
            gui_ResolveLayout()
        End If

        curr = curr->next_widget
    Wend

    gui_UpdateInProgress = 0
    input_SetDispatchMask -1, -1

    If widget_pending_front <> 0 Then
        Dim As Widget Ptr pendingFront = widget_pending_front
        widget_pending_front = 0
        gui_BringToFront pendingFront
    End If
End Sub

Sub gui_RenderAll()
    Dim As Integer bottomEdge
    Dim As Integer leftEdge
    Dim As Integer rightEdge
    Dim As Integer screenHeight
    Dim As Integer screenWidth
    Dim As Integer topEdge
    Dim As Integer clipHeight
    Dim As Integer clipWidth
    Dim As Integer clipX
    Dim As Integer clipY

    Dim As Widget Ptr curr = widget_list_head

    gui_ResolveLayout()
    backend_GetSize screenWidth, screenHeight

    While curr <> 0
        If curr->evis Then
            /'
                A modal root limits input, but the normal desktop remains
                visible behind its dialog. Normalizing the rectangle also
                preserves imported line widgets whose width or height is
                intentionally negative.
            '/
            leftEdge = curr->ax
            topEdge = curr->ay
            rightEdge = curr->ax + curr->w
            bottomEdge = curr->ay + curr->h

            If rightEdge < leftEdge Then Swap rightEdge, leftEdge
            If bottomEdge < topEdge Then Swap bottomEdge, topEdge
            If rightEdge = leftEdge Then rightEdge += 1
            If bottomEdge = topEdge Then bottomEdge += 1

            If leftEdge < screenWidth AndAlso topEdge < screenHeight AndAlso _
               rightEdge > 0 AndAlso bottomEdge > 0 Then
                If gui_GetWidgetRenderClip( _
                    curr, clipX, clipY, clipWidth, clipHeight _
                ) Then
                    backend_SetClip clipX, clipY, clipWidth, clipHeight
                    If curr->render <> 0 Then curr->render(curr)
                    backend_ResetClip
                End If
            End If
        End If
        curr = curr->next_widget
    Wend
End Sub


' -------------------------------------------------------------------------
' High-level primitives
' -------------------------------------------------------------------------

Sub gui_DrawLine( _
    ByVal x1 As Integer, ByVal y1 As Integer, _
    ByVal x2 As Integer, ByVal y2 As Integer, _
    ByVal clr As ULong _
)
    backend_Line x1, y1, x2, y2, clr
End Sub


Sub gui_DrawRect( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal clr As ULong, ByVal filled As Integer _
)
    backend_Rect x, y, w, h, clr, filled
End Sub


Sub gui_DrawCircle( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal radius As Integer, ByVal clr As ULong, _
    ByVal filled As Integer _
)
    backend_Circle x, y, radius, clr, filled
End Sub


Sub gui_DrawCurve( _
    ByVal x1 As Integer, ByVal y1 As Integer, _
    ByVal x2 As Integer, ByVal y2 As Integer, _
    ByVal x3 As Integer, ByVal y3 As Integer, _
    ByVal clr As ULong _
)
    backend_Curve x1, y1, x2, y2, x3, y3, clr
End Sub


' end of widgets.bas

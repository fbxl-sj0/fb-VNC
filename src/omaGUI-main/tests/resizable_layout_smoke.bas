/'
    Project: omaGUI
    ---------------

    File: resizable_layout_smoke.bas

    Purpose:
        Verify resizable gfxlib windows and reusable reactive widget anchors.

    Responsibilities:
        - confirm the backend requests a resizable native window
        - resize and maximize the real Windows editor-style surface
        - verify right, bottom, stretch, and centered anchor behavior
        - exercise page flipping after framebuffer dimensions change

    This file intentionally does NOT contain:
        - JRPG editor-specific layout rules
        - interactive input or visual approval
        - application data loading
'/

#lang "fb"

#include once "windows.bi"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

' -------------------------------------------------------------------------
' Test constants and failure handling
' -------------------------------------------------------------------------

Const RESIZE_SMOKE_INITIAL_W As Integer = 640
Const RESIZE_SMOKE_INITIAL_H As Integer = 480
Const RESIZE_SMOKE_LAYOUT_W As Integer = 900
Const RESIZE_SMOKE_LAYOUT_H As Integer = 700
Const RESIZE_SMOKE_POLL_COUNT As Integer = 200
Const RESIZE_SMOKE_POLL_MILLISECONDS As Integer = 10


Sub resize_smoke_Fail(ByVal messageText As String, ByVal exitCode As Integer)
    backend_Exit
    Screen 0
    Print "resizable layout smoke failed: " & messageText
    End exitCode
End Sub


' -------------------------------------------------------------------------
' Backend window and reactive widget layout
' -------------------------------------------------------------------------

backend_Init _
    RESIZE_SMOKE_INITIAL_W, RESIZE_SMOKE_INITIAL_H, 1, _
    BACKEND_WINDOW_RESIZABLE

Dim As Integer initialDrawableWidth
Dim As Integer initialDrawableHeight
ScreenInfo initialDrawableWidth, initialDrawableHeight

If initialDrawableWidth <> RESIZE_SMOKE_INITIAL_W OrElse _
   initialDrawableHeight <> RESIZE_SMOKE_INITIAL_H Then
    resize_smoke_Fail "gfxlib did not create the requested screen mode", 1
End If

If backend_IsResizable() = 0 Then
    resize_smoke_Fail "backend did not retain the resizable capability", 2
End If

gui_Init

Dim As Widget Ptr dock = subwindow_Create( _
    "resize_dock", "Dock", 400, 40, 200, 300 _
)
Dim As Widget Ptr bottomButton = button_Create( _
    "resize_bottom", "Bottom", 10, 260, 80, 24, 0 _
)
Dim As Widget Ptr centered = button_Create( _
    "resize_center", "Center", 100, 100, 80, 24, 0 _
)
Dim As Widget Ptr stretch = button_Create( _
    "resize_stretch", "Stretch", 20, 380, 560, 24, 0 _
)

If dock = 0 OrElse bottomButton = 0 OrElse centered = 0 OrElse _
   stretch = 0 Then
    resize_smoke_Fail "widget allocation failed", 3
End If

gui_AddWidget dock
gui_AddWidget bottomButton
gui_AddWidget centered
gui_AddWidget stretch
gui_SetParent bottomButton, dock
gui_SetAnchors dock, _
    GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP Or GUI_ANCHOR_BOTTOM
gui_SetAnchors bottomButton, GUI_ANCHOR_LEFT Or GUI_ANCHOR_BOTTOM
gui_SetAnchors centered, GUI_ANCHOR_NONE
gui_SetAnchors stretch, _
    GUI_ANCHOR_LEFT Or GUI_ANCHOR_RIGHT Or GUI_ANCHOR_TOP
gui_SetViewportSize RESIZE_SMOKE_LAYOUT_W, RESIZE_SMOKE_LAYOUT_H

If dock->x <> 660 OrElse dock->y <> 40 OrElse _
   dock->w <> 200 OrElse dock->h <> 520 Then
    resize_smoke_Fail "right dock anchors produced the wrong rectangle", 4
End If

If bottomButton->x <> 10 OrElse bottomButton->y <> 480 OrElse _
   bottomButton->w <> 80 OrElse bottomButton->h <> 24 Then
    resize_smoke_Fail "child bottom anchor did not follow its parent", 5
End If

If centered->x <> 230 OrElse centered->y <> 210 Then
    resize_smoke_Fail "unanchored axes did not remain centered", 6
End If

If stretch->x <> 20 OrElse stretch->y <> 380 OrElse _
   stretch->w <> 820 OrElse stretch->h <> 24 Then
    resize_smoke_Fail "opposing horizontal anchors did not stretch", 7
End If

/'
    gfxlib owns its window on another thread. SetWindowPos and ShowWindow are
    therefore followed by bounded polling of the drawable dimensions rather
    than a timing-sensitive fixed delay.
'/
Dim As LongInt nativeHandleValue
Dim As HWND nativeHandle
Dim As Integer drawableWidth
Dim As Integer drawableHeight
Dim As Integer resizedWidth
Dim As Integer resizedHeight

ScreenControl FB.GET_WINDOW_HANDLE, nativeHandleValue
nativeHandle = Cast(HWND, nativeHandleValue)

If nativeHandle = 0 Then
    resize_smoke_Fail "gfxlib did not expose a native window handle", 8
End If

ShowWindow nativeHandle, SW_RESTORE
SetWindowPos _
    nativeHandle, 0, 0, 0, RESIZE_SMOKE_LAYOUT_W, RESIZE_SMOKE_LAYOUT_H, _
    SWP_NOMOVE Or SWP_NOZORDER

For pollIndex As Integer = 1 To RESIZE_SMOKE_POLL_COUNT
    backend_GetSize drawableWidth, drawableHeight
    If drawableWidth > RESIZE_SMOKE_INITIAL_W AndAlso _
       drawableHeight > RESIZE_SMOKE_INITIAL_H Then Exit For
    Sleep RESIZE_SMOKE_POLL_MILLISECONDS, 1
Next pollIndex

If drawableWidth <= RESIZE_SMOKE_INITIAL_W OrElse _
   drawableHeight <= RESIZE_SMOKE_INITIAL_H Then
    resize_smoke_Fail "native resize did not enlarge the drawable area", 9
End If

resizedWidth = drawableWidth
resizedHeight = drawableHeight
backend_Clear RGB(24, 32, 40)
backend_Flip

ShowWindow nativeHandle, SW_MAXIMIZE

For pollIndex As Integer = 1 To RESIZE_SMOKE_POLL_COUNT
    backend_GetSize drawableWidth, drawableHeight
    If drawableWidth > resizedWidth OrElse drawableHeight > resizedHeight Then _
        Exit For
    Sleep RESIZE_SMOKE_POLL_MILLISECONDS, 1
Next pollIndex

If drawableWidth <= resizedWidth AndAlso drawableHeight <= resizedHeight Then
    resize_smoke_Fail "maximize did not change the drawable area", 10
End If

gui_UpdateAll
gui_GetViewportSize resizedWidth, resizedHeight

If resizedWidth <> drawableWidth OrElse resizedHeight <> drawableHeight Then
    resize_smoke_Fail "GUI viewport did not react to the backend resize", 11
End If

backend_Clear RGB(40, 32, 24)
gui_RenderAll
backend_Flip

backend_Exit
Screen 0
Print "resizable layout smoke passed"

' end of resizable_layout_smoke.bas

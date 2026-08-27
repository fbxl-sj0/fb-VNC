/'
    Project: omaGUI
    ---------------

    File: subwindow.bi

    Purpose:
        Declare movable, ordered, closable child windows.

    Responsibilities:
        - expose subwindow construction and lifecycle operations
        - retain dragging and close-button state
        - expose an optional application close callback

    This file intentionally does NOT contain:
        - window ordering policy
        - child rendering or input clipping policy
        - platform-native window management
'/

#ifndef __SUBWINDOW_BI__
#define __SUBWINDOW_BI__

#include once "src/widgets/widgets.bi"

Type SubWindowData
    As String title
    As Integer dragging
    As Integer drag_off_x, drag_off_y
    As Integer closable
    As Integer close_requested
    As Integer close_latch
    As Any Ptr close_handler
End Type

Declare Function subwindow_Create( _
    ByVal nm As String, ByVal title As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal closable As Integer = -1 _
) As Widget Ptr
Declare Sub subwindow_SetCloseHandler( _
    ByVal w As Widget Ptr, ByVal closeHandler As Any Ptr _
)
Declare Sub subwindow_SetClosable( _
    ByVal w As Widget Ptr, ByVal closable As Integer _
)
Declare Function subwindow_CloseRequested(ByVal w As Widget Ptr) As Integer
Declare Sub subwindow_Reopen(ByVal w As Widget Ptr)
Declare Sub subwindow_Render(ByVal w As Widget Ptr)
Declare Sub subwindow_Update(ByVal w As Widget Ptr)
Declare Sub subwindow_Destroy(ByVal w As Widget Ptr)

#endif

/' end of subwindow.bi '/

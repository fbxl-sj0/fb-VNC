/'
    Project: omaGUI
    ---------------
    File: widgets.bi

    Purpose:

        Central widget registry and base structure definitions.

    Responsibilities:

        - define the base Widget structure
        - declare the global GUI manager API
        - define widget lifecycle callbacks
        - expose anchor constraints for reactive window layouts

    This file intentionally does NOT contain:

        - individual widget implementation logic
        - graphics backend code
'/

#ifndef __WIDGETS_BI__
#define __WIDGETS_BI__

#include "src/backend/backend.bi"
#include "src/backend/input.bi"

' -------------------------------------------------------------------------
' Type Definitions
' -------------------------------------------------------------------------

Type Widget_Struct_
    As String name
    As Integer x, y, w, h
    As Integer ax, ay
    As Integer visible
    As Integer enabled
    As Integer evis
    As Integer een
    As Integer updated_this_frame
    As Integer accepts_focus
    As Integer has_focus
    As Integer is_window
    As Integer pointer_global
    As Integer clip_children
    As Integer child_clip_x, child_clip_y
    As Integer child_clip_right, child_clip_bottom
    As Any Ptr data

    /'
        Reactive layout is opt-in. The saved rectangle and container size are
        the stable reference used when a window or parent changes dimensions.
        Widgets without layout_initialized retain the original absolute or
        parent-relative behavior.
    '/
    As UInteger anchor_flags
    As Integer layout_initialized
    As Integer layout_base_x, layout_base_y
    As Integer layout_base_w, layout_base_h
    As Integer layout_container_w, layout_container_h
    As UInteger layout_generation

    ' Callbacks
    As Sub(ByVal As Widget_Struct_ Ptr) render
    As Sub(ByVal As Widget_Struct_ Ptr) update
    As Sub(ByVal As Widget_Struct_ Ptr) destroy

    As Widget_Struct_ Ptr parent
    As Widget_Struct_ Ptr next_widget
End Type

Type Widget As Widget_Struct_

' -------------------------------------------------------------------------
' GUI Manager API
' -------------------------------------------------------------------------

Const GUI_ANCHOR_NONE As UInteger = 0
Const GUI_ANCHOR_LEFT As UInteger = 1
Const GUI_ANCHOR_TOP As UInteger = 2
Const GUI_ANCHOR_RIGHT As UInteger = 4
Const GUI_ANCHOR_BOTTOM As UInteger = 8
Const GUI_ANCHOR_ALL As UInteger = _
    GUI_ANCHOR_LEFT Or GUI_ANCHOR_TOP Or _
    GUI_ANCHOR_RIGHT Or GUI_ANCHOR_BOTTOM

/'
    Anchor behavior follows desktop GUI conventions. Anchoring both opposing
    edges stretches that axis, anchoring only the far edge moves the widget,
    anchoring only the near edge preserves its local rectangle, and selecting
    neither edge keeps the widget centered as its container changes size.
'/

Declare Sub gui_Init()
Declare Sub gui_ResetForTest()
Declare Sub gui_AddWidget(ByVal w As Widget Ptr)
Declare Sub gui_AddGeneratedWidget(ByVal w As Widget Ptr)
Declare Sub gui_RemoveWidget(ByVal nm As String)
Declare Function gui_FindWidget(ByVal nm As String) As Widget Ptr
Declare Sub gui_SetParent(ByVal child As Widget Ptr, ByVal parent As Widget Ptr)
Declare Sub gui_BringToFront(ByVal w As Widget Ptr)
Declare Sub gui_SetFocus(ByVal w As Widget Ptr)
Declare Function gui_GetFocus() As Widget Ptr
Declare Sub gui_SetModalRoot(ByVal root As Widget Ptr)
Declare Sub gui_ClearModalRoot(ByVal root As Widget Ptr = 0)
Declare Function gui_IsModalOpen() As Integer
Declare Sub gui_SetViewportSize(ByVal w As Integer, ByVal h As Integer)
Declare Sub gui_GetViewportSize(ByRef w As Integer, ByRef h As Integer)
Declare Sub gui_SetAnchors(ByVal w As Widget Ptr, ByVal anchorFlags As UInteger)
Declare Sub gui_ResetAnchors(ByVal w As Widget Ptr)

Declare Sub gui_UpdateAll()
Declare Sub gui_RenderAll()

Declare Sub gui_DrawLine( _
    ByVal x1 As Integer, ByVal y1 As Integer, _
    ByVal x2 As Integer, ByVal y2 As Integer, _
    ByVal clr As ULong _
)
Declare Sub gui_DrawRect( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal clr As ULong, ByVal filled As Integer _
)
Declare Sub gui_DrawCircle( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal radius As Integer, ByVal clr As ULong, _
    ByVal filled As Integer _
)
Declare Sub gui_DrawCurve( _
    ByVal x1 As Integer, ByVal y1 As Integer, _
    ByVal x2 As Integer, ByVal y2 As Integer, _
    ByVal x3 As Integer, ByVal y3 As Integer, _
    ByVal clr As ULong _
)

Declare Function gui_ButtonPressed(ByVal nm As String) As Integer
Declare Sub gui_DeselectRadioGroup(ByVal group_id As Integer, ByVal caller As Widget Ptr)

#endif

/' end of widgets.bi '/

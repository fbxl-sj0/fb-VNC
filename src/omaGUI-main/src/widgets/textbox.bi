/'
    Project: omaGUI
    ---------------

    File: textbox.bi

    Purpose:

        Declare the reusable editable text widget used by editor popups and
        ordinary single-line controls.

    Responsibilities:

        - define textbox state owned by each widget
        - expose textbox construction and update/render entry points
        - retain bounded per-widget text undo and redo state
        - retain mouse-drag and keyboard selection state
        - expose configurable multiline vertical scrollbar behavior

    This file intentionally does NOT contain:

        - clipboard implementation
        - keyboard polling
        - application-specific text validation
'/

#ifndef __TEXTBOX_BI__
#define __TEXTBOX_BI__
#include once "src/widgets/widgets.bi"

Const TEXTBOX_HISTORY_MAX_ENTRIES As Integer = 16
Const TEXTBOX_HISTORY_MAX_STORED_BYTES As Integer = 2097152
Const TEXTBOX_HISTORY_GROUP_NONE As Integer = 0
Const TEXTBOX_HISTORY_GROUP_TYPING As Integer = 1
Const TEXTBOX_HISTORY_GROUP_BACKSPACE As Integer = 2
Const TEXTBOX_HISTORY_GROUP_DELETE As Integer = 3
Const TEXTBOX_HISTORY_GROUP_RETURN As Integer = 4

Const TEXTBOX_SCROLLBAR_NONE As Integer = 0
Const TEXTBOX_SCROLLBAR_AUTO As Integer = 1
Const TEXTBOX_SCROLLBAR_ALWAYS As Integer = 2

Type TextBoxHistoryEntry
    As String text
    As Integer cursor_pos, sel_start, sel_end, selection_anchor
    As Integer scroll_offset, v_scroll
End Type

Type TextBoxData
    As String text
    As Integer active, multiline, wordwrap
    As Integer cursor_pos, sel_start, sel_end, selection_anchor
    As Integer scroll_offset, v_scroll
    As Integer key_latch
    As Integer mouse_latch, mouse_selecting
    As Integer scrollbar_dragging
    As Integer scrollbar_mode, scrollbar_visible
    As Integer total_visual_lines
    As Integer viewport_dirty
    As Integer observed_text_length, observed_cursor_pos
    As Widget Ptr vertical_scrollbar
    As TextBoxHistoryEntry undoEntries(0 To TEXTBOX_HISTORY_MAX_ENTRIES - 1)
    As TextBoxHistoryEntry redoEntries(0 To TEXTBOX_HISTORY_MAX_ENTRIES - 1)
    As Integer undoCount, redoCount
    As LongInt historyStoredBytes
    As Integer historyGroup, historyIdleFrames
End Type
Declare Function textbox_Create( _
    ByVal nm As String, ByVal txt As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal m As Integer, ByVal ww As Integer, _
    ByVal scrollbarMode As Integer = TEXTBOX_SCROLLBAR_AUTO _
) As Widget Ptr
Declare Sub textbox_Render(ByVal w As Widget Ptr)
Declare Sub textbox_Update(ByVal w As Widget Ptr)
Declare Sub textbox_Destroy(ByVal w As Widget Ptr)
Declare Sub textbox_ClearHistory(ByVal w As Widget Ptr)
Declare Function textbox_BeginEdit( _
    ByVal w As Widget Ptr, _
    ByVal groupId As Integer = TEXTBOX_HISTORY_GROUP_NONE _
) As Integer
Declare Sub textbox_EndEditGroup(ByVal w As Widget Ptr)
Declare Function textbox_Undo(ByVal w As Widget Ptr) As Integer
Declare Function textbox_Redo(ByVal w As Widget Ptr) As Integer
Declare Function textbox_SetText( _
    ByVal w As Widget Ptr, _
    ByVal textValue As String, _
    ByVal resetHistory As Integer _
) As Integer
Declare Sub textbox_SetVerticalScrollbar( _
    ByVal w As Widget Ptr, ByVal scrollbarMode As Integer _
)
Declare Function textbox_GetVerticalScrollbarMode( _
    ByVal w As Widget Ptr _
) As Integer
#endif

' end of textbox.bi

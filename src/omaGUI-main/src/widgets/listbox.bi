/'
    Project: omaGUI
    ---------------

    File: listbox.bi

    Purpose:

        Declare the fixed-capacity scrolling list widget used by editor
        catalogs and choice dialogs.

    Responsibilities:

        - define bounded list item, selection, and scroll state
        - expose list creation, update, rendering, and item operations

    This file intentionally does NOT contain:

        - list rendering implementation
        - application-specific filtering or persistence
        - keyboard or mouse backend implementation
'/

#ifndef __LISTBOX_BI__
#define __LISTBOX_BI__

#include once "src/widgets/widgets.bi"

Const LISTBOX_MAX_ITEMS As Integer = 1024

Type ListBoxData
    As String items(0 To LISTBOX_MAX_ITEMS - 1)
    As Integer item_count
    As Integer selected_index
    As Integer scroll_top
    As Integer key_latch
    As Widget Ptr scrollbar
End Type

Declare Function listbox_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer) As Widget Ptr
Declare Sub listbox_Render(ByVal w As Widget Ptr)
Declare Sub listbox_Update(ByVal w As Widget Ptr)
Declare Sub listbox_Destroy(ByVal w As Widget Ptr)
Declare Sub listbox_AddItem(ByVal w As Widget Ptr, ByVal lbl As String)
Declare Sub listbox_Clear(ByVal w As Widget Ptr)
Declare Function listbox_GetSelectedIndex(ByVal w As Widget Ptr) As Integer
Declare Function listbox_GetSelectedItem(ByVal w As Widget Ptr) As String

#endif

/' end of listbox.bi '/

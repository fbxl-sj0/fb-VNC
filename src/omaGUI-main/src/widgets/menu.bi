/'
    Project: omaGUI
    ---------------

    File: menu.bi

    Purpose:

        Declare a bounded popup menu used directly and by imported dropdowns.

    Responsibilities:

        - retain menu labels, hover selection, and callbacks
        - support per-item callbacks or one context-aware selection handler
        - expose item reset for reusable generated popups

    This file intentionally does NOT contain:

        - application command policy
        - imported-control ownership rules
        - global pointer-routing policy
'/

#ifndef __MENU_BI__
#define __MENU_BI__

#include once "src/widgets/widgets.bi"

Const MENU_MAX_ITEMS As Integer = 32

Type MenuData
    As String items(0 To MENU_MAX_ITEMS - 1)
    As Sub(ByVal As Integer) callbacks(0 To MENU_MAX_ITEMS - 1)
    As Integer count, selected
    As Any Ptr selection_handler, selection_context
End Type

Declare Function menu_Create( _
    ByVal nm As String, ByVal x As Integer, ByVal y As Integer _
) As Widget Ptr
Declare Sub menu_AddItem( _
    ByVal m As Widget Ptr, ByVal txt As String, _
    ByVal cb As Sub(ByVal As Integer) _
)
Declare Sub menu_ClearItems(ByVal m As Widget Ptr)
Declare Sub menu_SetSelectionHandler( _
    ByVal m As Widget Ptr, _
    ByVal selection_handler As Any Ptr, _
    ByVal selection_context As Any Ptr _
)
Declare Sub menu_Render(ByVal w As Widget Ptr)
Declare Sub menu_Update(ByVal w As Widget Ptr)
Declare Sub menu_Destroy(ByVal w As Widget Ptr)

#endif

' end of menu.bi

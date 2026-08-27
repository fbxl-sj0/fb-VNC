/'
    Project: omaGUI
    ---------------

    File: checkbox.bi

    Purpose:

        Declare a labeled boolean checkbox widget.

    Responsibilities:

        - retain the displayed label and checked state
        - expose checkbox creation and widget lifecycle entry points

    This file intentionally does NOT contain:

        - rendering or pointer-update implementation
        - application-specific state synchronization
'/

#ifndef __CHECKBOX_BI__
#define __CHECKBOX_BI__

#include once "src/widgets/widgets.bi"

Type CheckBoxData
    As String label
    As Integer checked, last_mb
End Type

Declare Function checkbox_Create( _
    ByVal nm As String, ByVal lbl As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal checked As Integer = 0 _
) As Widget Ptr
Declare Sub checkbox_Render(ByVal w As Widget Ptr)
Declare Sub checkbox_Update(ByVal w As Widget Ptr)
Declare Sub checkbox_Destroy(ByVal w As Widget Ptr)

#endif

' end of checkbox.bi

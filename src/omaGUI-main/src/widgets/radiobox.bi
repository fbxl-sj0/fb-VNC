/'
    Project: omaGUI
    ---------------

    File: radiobox.bi

    Purpose:

        Declare a labeled radio-button widget with registry-wide grouping.

    Responsibilities:

        - retain group and selected state
        - expose radio-button creation and widget lifecycle entry points

    This file intentionally does NOT contain:

        - group traversal implementation
        - application-specific option semantics
'/

#ifndef __RADIOBOX_BI__
#define __RADIOBOX_BI__

#include once "src/widgets/widgets.bi"

Type RadioBoxData
    As String label
    As Integer group_id, selected, last_mb
End Type

Declare Function radiobox_Create( _
    ByVal nm As String, ByVal lbl As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal gid As Integer, ByVal s As Integer = 0 _
) As Widget Ptr
Declare Sub radiobox_Render(ByVal w As Widget Ptr)
Declare Sub radiobox_Update(ByVal w As Widget Ptr)
Declare Sub radiobox_Destroy(ByVal w As Widget Ptr)

#endif

' end of radiobox.bi

/'
    Project: omaGUI
    ---------------

    File: label.bi

    Purpose:

        Declare a noninteractive text-label widget.

    Responsibilities:

        - retain label text and color
        - expose label creation and rendering lifecycle entry points

    This file intentionally does NOT contain:

        - text editing or input handling
        - font-layout policy beyond the backend default font
'/

#ifndef __LABEL_BI__
#define __LABEL_BI__

#include once "src/widgets/widgets.bi"

Type LabelData
    As String text
    As ULong clr
End Type

Declare Function label_Create( _
    ByVal nm As String, ByVal txt As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal clr As ULong = RGB(0, 0, 0) _
) As Widget Ptr
Declare Sub label_Render(ByVal w As Widget Ptr)
Declare Sub label_Destroy(ByVal w As Widget Ptr)

#endif

' end of label.bi

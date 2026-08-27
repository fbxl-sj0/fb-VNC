/'
    Project: omaGUI
    ---------------

    File: button.bi

    Purpose:

        Declare the classic push-button widget.

    Responsibilities:

        - retain the button label and pointer state
        - expose callback-driven and polled activation

    This file intentionally does NOT contain:

        - button rendering implementation
        - global focus or pointer-routing policy
        - application command handling
'/

#ifndef __BUTTON_BI__
#define __BUTTON_BI__

#include once "src/widgets/widgets.bi"

Type ButtonData
    As String text
    As Integer pressed, state
    As Any Ptr clickHandler
End Type

Declare Function button_Create( _
    ByVal nm As String, ByVal txt As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal clickHandler As Any Ptr = 0 _
) As Widget Ptr
Declare Sub button_Render(ByVal w As Widget Ptr)
Declare Sub button_Update(ByVal w As Widget Ptr)
Declare Sub button_Destroy(ByVal w As Widget Ptr)

#endif

' end of button.bi

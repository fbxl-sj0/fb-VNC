/'
    Project: omaGUI
    ---------------

    File: scrollbar.bi

    Purpose:
        Declare horizontal and vertical scrollbar widgets.

    Responsibilities:
        - retain bounded value, range, page, and orientation state
        - expose scrollbar construction, rendering, and input handling

    This file intentionally does NOT contain:
        - list ownership
        - global wheel dispatch
        - application-specific value interpretation
'/

#ifndef __SCROLLBAR_BI__
#define __SCROLLBAR_BI__
#include once "src/widgets/widgets.bi"
Type ScrollBarData : As Integer value, max_val, page_size, vertical : End Type
Declare Function scrollbar_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal mv As Integer, ByVal ps As Integer = 10, ByVal v As Integer = 1) As Widget Ptr
Declare Sub scrollbar_Render(ByVal w As Widget Ptr)
Declare Sub scrollbar_Update(ByVal w As Widget Ptr)
Declare Sub scrollbar_Destroy(ByVal w As Widget Ptr)
#endif

/' end of scrollbar.bi '/

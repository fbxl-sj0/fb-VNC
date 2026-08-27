/'
    Project: omaGUI
    ---------------

    File: confirmdialog.bi

    Purpose:

        Declare a modal confirmation window for actions that need an explicit
        user decision before discarding or replacing application state.

    Responsibilities:

        - create a yes-or-cancel modal window
        - expose the completed result to the owning application

    This file intentionally does NOT contain:

        - application-specific confirmation policy
        - file operations
        - platform-native dialog calls
'/

#ifndef __CONFIRMDIALOG_BI__
#define __CONFIRMDIALOG_BI__

#include once "src/widgets/widgets.bi"

Declare Function confirmdialog_Create( _
    ByVal nm As String, _
    ByVal title As String, _
    ByVal message As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal confirmText As String = "Discard" _
) As Widget Ptr
Declare Function confirmdialog_GetResultState(ByVal w As Widget Ptr) As Integer

#endif

' end of confirmdialog.bi

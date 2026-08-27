/'
    Project: omaGUI
    ---------------

    File: filedialog.bi

    Purpose:

        Declare the file dialog widget interface.

    Responsibilities:

        - expose file dialog construction
        - expose selected-file and dialog-result queries
        - allow callers to select an initial directory without changing CurDir
        - expose an optional save mode with a caller-supplied default name

    This file intentionally does NOT contain:

        - directory enumeration implementation
        - rendering logic
        - editor-specific file handling
'/

#ifndef __FILEDIALOG_BI__
#define __FILEDIALOG_BI__

#include once "src/widgets/widgets.bi"

Const FILEDIALOG_MODE_OPEN As Integer = 0
Const FILEDIALOG_MODE_SAVE As Integer = 1

Declare Function filedialog_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer) As Widget Ptr
Declare Function filedialog_CreateAtPath( _
    ByVal nm As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal initialPath As String _
) As Widget Ptr
Declare Function filedialog_CreateSaveAtPath( _
    ByVal nm As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal initialPath As String, _
    ByVal initialFilename As String _
) As Widget Ptr
Declare Function filedialog_GetSelectedFile(ByVal w As Widget Ptr) As String
Declare Function filedialog_GetResultState(ByVal w As Widget Ptr) As Integer

#endif

/' end of filedialog.bi '/

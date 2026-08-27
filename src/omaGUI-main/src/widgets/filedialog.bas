/'
    Project: omaGUI
    ---------------

    File: filedialog.bas

    Purpose:

        Implement a generated-widget file dialog.

    Responsibilities:

        - show directory contents in an omaGUI list box
        - navigate directories through dialog-owned path state
        - collect an optional safe filename for save operations
        - report accepted and cancelled dialog states
        - claim modal update focus while the dialog is open

    This file intentionally does NOT contain:

        - editor save/load policy
        - platform-native file dialog calls
        - map serialization logic
'/

#lang "fb"
#include once "src/widgets/filedialog.bi"
#include once "src/widgets/subwindow.bi"
#include once "src/widgets/listbox.bi"
#include once "src/widgets/button.bi"
#include once "src/widgets/label.bi"

#include once "dir.bi"
#include once "vbcompat.bi"

#if defined(__FB_WIN32__)
#include once "windows.bi"
#endif

Type FileDialogData
    As Widget Ptr win
    As Widget Ptr lst
    As Widget Ptr btn_ok
    As Widget Ptr btn_cancel
    As Widget Ptr filenameBox
    As String current_path
    As String selected_file
    As Integer mode
    As Integer finished
End Type


' -------------------------------------------------------------------------
' Path helpers
' -------------------------------------------------------------------------

#If Defined(__FB_WIN32__)
Const FILEDIALOG_PATH_SEPARATOR As String = "\"
#Else
Const FILEDIALOG_PATH_SEPARATOR As String = "/"
#EndIf

Const FILEDIALOG_WINDOW_WIDTH As Integer = 400
Const FILEDIALOG_WINDOW_HEIGHT As Integer = 340
Const FILEDIALOG_LIST_X As Integer = 10
Const FILEDIALOG_LIST_Y As Integer = 30
Const FILEDIALOG_LIST_WIDTH As Integer = 380
Const FILEDIALOG_LIST_HEIGHT As Integer = 184
Const FILEDIALOG_FILENAME_Y As Integer = 244
Const FILEDIALOG_FILENAME_HEIGHT As Integer = 24
Const FILEDIALOG_ACTION_Y As Integer = 292
Const FILEDIALOG_ACTION_WIDTH As Integer = 80
Const FILEDIALOG_ACTION_HEIGHT As Integer = 30
Const FILEDIALOG_ACCEPT_X As Integer = 220
Const FILEDIALOG_CANCEL_X As Integer = 310

Declare Function filedialog_CreateModeAtPath( _
    ByVal nm As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal initialPath As String, _
    ByVal initialFilename As String, _
    ByVal mode As Integer _
) As Widget Ptr


Private Function filedialog_JoinPath( _
    ByVal basePath As String, _
    ByVal childName As String _
) As String

    If Len(basePath) = 0 Then Return childName

    If Right(basePath, 1) = FILEDIALOG_PATH_SEPARATOR Then
        Return basePath & childName
    End If

    Return basePath & FILEDIALOG_PATH_SEPARATOR & childName

End Function


Private Function filedialog_GetParentPath(ByVal pathValue As String) As String

    Dim As Integer separatorPosition

    If Len(pathValue) = 0 Then Return ""

    separatorPosition = InStrRev(pathValue, FILEDIALOG_PATH_SEPARATOR)

    If separatorPosition = 0 Then Return pathValue
    If separatorPosition = 1 Then Return Left(pathValue, 1)

    ' Preserve a Windows volume root such as C:\ when navigating upward.
    If separatorPosition = 3 AndAlso Mid(pathValue, 2, 1) = ":" Then
        Return Left(pathValue, separatorPosition)
    End If

    Return Left(pathValue, separatorPosition - 1)

End Function


Private Function filedialog_IsSafeFilename(ByVal filename As String) As Integer

    filename = Trim(filename)

    If filename = "" OrElse filename = "." OrElse filename = ".." Then Return 0
    If InStr(filename, "/") <> 0 OrElse InStr(filename, "\") <> 0 Then Return 0
    If InStr(filename, ":") <> 0 Then Return 0

    Return -1

End Function


Private Function filedialog_FilenameText(ByVal dialogData As FileDialogData Ptr) As String

    If dialogData = 0 OrElse dialogData->filenameBox = 0 Then Return ""
    Return Trim(Cast(TextBoxData Ptr, dialogData->filenameBox->data)->text)

End Function


Private Sub filedialog_SetFilenameText( _
    ByVal dialogData As FileDialogData Ptr, _
    ByVal filename As String _
)

    If dialogData = 0 OrElse dialogData->filenameBox = 0 Then Exit Sub

    Cast(TextBoxData Ptr, dialogData->filenameBox->data)->text = filename

End Sub


Private Sub filedialog_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then Delete Cast(FileDialogData Ptr, w->data)
End Sub

Private Function filedialog_GetRoot(ByVal w As Widget Ptr) As Widget Ptr
    Dim As Widget Ptr curr = w
    While curr <> 0
        If curr->parent = 0 Then Return curr
        curr = curr->parent
    Wend
    Return 0
End Function

#if defined(__FB_WIN32__)

Private Sub filedialog_RefreshWindowsEntries( _
    ByVal dialogData As FileDialogData Ptr, _
    ByVal searchPattern As String, _
    ByVal wantDirectories As Integer _
)
    Dim As WIN32_FIND_DATAA findData
    Dim As HANDLE findHandle
    Dim As WINBOOL closeResult
    Dim As String entryName
    Dim As Integer isDirectory

    ' Win32 reserves bit 4 in dwFileAttributes for directory entries.
    Const FILEDIALOG_WINDOWS_DIRECTORY_ATTRIBUTE As UInteger = &h10

    If dialogData = 0 OrElse dialogData->lst = 0 Then Exit Sub

    findHandle = FindFirstFileA(StrPtr(searchPattern), @findData)
    If CLngInt(findHandle) = -1 Then Exit Sub

    Do
        entryName = findData.cFileName
        isDirectory = IIf( _
            (findData.dwFileAttributes And _
                FILEDIALOG_WINDOWS_DIRECTORY_ATTRIBUTE) <> 0, _
            -1, 0 _
        )

        If wantDirectories <> 0 Then
            If isDirectory <> 0 AndAlso entryName <> "." AndAlso _
               entryName <> ".." Then
                listbox_AddItem dialogData->lst, "[" & entryName & "]"
            End If
        ElseIf isDirectory = 0 Then
            listbox_AddItem dialogData->lst, entryName
        End If
    Loop While FindNextFileA(findHandle, @findData) <> 0

    closeResult = FindClose(findHandle)
End Sub

#endif

Private Sub filedialog_Refresh(ByVal root As Widget Ptr)
    Dim As FileDialogData Ptr d = root->data
    Dim As String searchPattern

    If d = 0 Then Exit Sub

    listbox_Clear(d->lst)
    listbox_AddItem(d->lst, "..")

    Dim As Integer out_attr
    searchPattern = filedialog_JoinPath(d->current_path, "*")

#if defined(__FB_WIN32__)
    /'
        The current Windows runtime's generic Dir("*") search exposes
        directories but omits ordinary files. The Win32 iterator returns both
        kinds from one documented filesystem API and preserves their attrs.
    '/
    filedialog_RefreshWindowsEntries d, searchPattern, 1
    filedialog_RefreshWindowsEntries d, searchPattern, 0
#else
    Dim As String f = Dir(searchPattern, fbDirectory, out_attr)
    While f <> ""
        If f <> "." And f <> ".." Then
            If (out_attr And fbDirectory) <> 0 Then listbox_AddItem(d->lst, "[" & f & "]")
        End If
        f = Dir(out_attr)
    Wend

    f = Dir(searchPattern, fbNormal Or fbReadOnly Or fbHidden Or fbSystem Or fbArchive, out_attr)
    While f <> ""
        If (out_attr And fbDirectory) = 0 Then listbox_AddItem(d->lst, f)
        f = Dir(out_attr)
    Wend
#endif
End Sub

Private Sub filedialog_OnOK(ByVal w As Widget Ptr)
    Dim As Widget Ptr root
    Dim As FileDialogData Ptr d
    Dim As ListBoxData Ptr ld
    Dim As String sel
    Dim As String filename

    root = filedialog_GetRoot(w)
    If root = 0 Then Exit Sub

    d = root->data
    If d = 0 OrElse d->lst = 0 Then Exit Sub

    ld = d->lst->data
    If ld = 0 Then Exit Sub

    sel = ""

    If ld->selected_index >= 0 AndAlso ld->selected_index < ld->item_count Then
        sel = ld->items(ld->selected_index)

        If Left(sel, 1) = "[" Then
            Dim As String dirName = Mid(sel, 2, Len(sel) - 2)
            d->current_path = filedialog_JoinPath(d->current_path, dirName)
            filedialog_Refresh(root)
            Exit Sub
        Elseif sel = ".." Then
            d->current_path = filedialog_GetParentPath(d->current_path)
            filedialog_Refresh(root)
            Exit Sub
        End If
    End If

    If d->mode = FILEDIALOG_MODE_SAVE Then
        If sel <> "" Then filedialog_SetFilenameText d, sel

        filename = filedialog_FilenameText(d)
        If filedialog_IsSafeFilename(filename) = 0 Then Exit Sub

        d->selected_file = filedialog_JoinPath(d->current_path, filename)
        d->finished = 1
    ElseIf sel <> "" Then
        d->selected_file = filedialog_JoinPath(d->current_path, sel)
        d->finished = 1
    End If
End Sub

Private Sub filedialog_OnCancel(ByVal w As Widget Ptr)
    Dim As Widget Ptr root = filedialog_GetRoot(w)
    If root <> 0 Then Cast(FileDialogData Ptr, root->data)->finished = -1
End Sub

Function filedialog_Create(ByVal nm As String, ByVal x As Integer, ByVal y As Integer) As Widget Ptr

    Return filedialog_CreateModeAtPath( _
        nm, x, y, CurDir, "", FILEDIALOG_MODE_OPEN _
    )

End Function


Function filedialog_CreateAtPath( _
    ByVal nm As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal initialPath As String _
) As Widget Ptr

    Return filedialog_CreateModeAtPath( _
        nm, x, y, initialPath, "", FILEDIALOG_MODE_OPEN _
    )

End Function


Function filedialog_CreateSaveAtPath( _
    ByVal nm As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal initialPath As String, _
    ByVal initialFilename As String _
) As Widget Ptr

    Return filedialog_CreateModeAtPath( _
        nm, x, y, initialPath, initialFilename, FILEDIALOG_MODE_SAVE _
    )

End Function


Private Function filedialog_CreateModeAtPath( _
    ByVal nm As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal initialPath As String, _
    ByVal initialFilename As String, _
    ByVal mode As Integer _
) As Widget Ptr

    Dim As Widget Ptr root = New Widget
    root->name = nm : root->x = x : root->y = y : root->w = 0 : root->h = 0
    root->visible = 1 : root->enabled = 1
    root->ax = x : root->ay = y
    root->evis = 1 : root->een = 1
    root->parent = 0 : root->next_widget = 0
    root->update = 0 : root->render = 0 : root->destroy = @filedialog_Destroy
    root->updated_this_frame = 0

    Dim As FileDialogData Ptr d = New FileDialogData
    d->current_path = Trim(initialPath)
    If d->current_path = "" Then d->current_path = CurDir
    d->selected_file = ""
    d->mode = mode
    d->finished = 0
    root->data = d

    /'
        The dialog root owns the requested screen position.  Its generated
        subwindow begins at local origin so parent-relative layout does not
        add the dialog offset twice.
    '/
    If d->mode = FILEDIALOG_MODE_SAVE Then
        d->win = subwindow_Create( _
            nm & "_win", "Save File", 0, 0, _
            FILEDIALOG_WINDOW_WIDTH, FILEDIALOG_WINDOW_HEIGHT _
        )
    Else
        d->win = subwindow_Create( _
            nm & "_win", "Select File", 0, 0, _
            FILEDIALOG_WINDOW_WIDTH, FILEDIALOG_WINDOW_HEIGHT _
        )
    End If
    subwindow_SetCloseHandler d->win, @filedialog_OnCancel
    gui_AddGeneratedWidget(d->win)
    gui_SetParent(d->win, root)

    d->lst = listbox_Create( _
        nm & "_lst", FILEDIALOG_LIST_X, FILEDIALOG_LIST_Y, _
        FILEDIALOG_LIST_WIDTH, FILEDIALOG_LIST_HEIGHT _
    )
    gui_AddGeneratedWidget(d->lst)
    gui_SetParent(d->lst, d->win)

    If d->mode = FILEDIALOG_MODE_SAVE Then
        d->filenameBox = textbox_Create( _
            nm & "_name", initialFilename, FILEDIALOG_LIST_X, _
            FILEDIALOG_FILENAME_Y, FILEDIALOG_LIST_WIDTH, _
            FILEDIALOG_FILENAME_HEIGHT, 0, 0 _
        )
        gui_AddGeneratedWidget(d->filenameBox)
        gui_SetParent(d->filenameBox, d->win)

        d->btn_ok = button_Create( _
            nm & "_ok", "Save", FILEDIALOG_ACCEPT_X, _
            FILEDIALOG_ACTION_Y, FILEDIALOG_ACTION_WIDTH, _
            FILEDIALOG_ACTION_HEIGHT, @filedialog_OnOK _
        )
    Else
        d->btn_ok = button_Create( _
            nm & "_ok", "Open", FILEDIALOG_ACCEPT_X, _
            FILEDIALOG_ACTION_Y, FILEDIALOG_ACTION_WIDTH, _
            FILEDIALOG_ACTION_HEIGHT, @filedialog_OnOK _
        )
    End If
    gui_AddGeneratedWidget(d->btn_ok)
    gui_SetParent(d->btn_ok, d->win)

    d->btn_cancel = button_Create( _
        nm & "_cancel", "Cancel", FILEDIALOG_CANCEL_X, _
        FILEDIALOG_ACTION_Y, FILEDIALOG_ACTION_WIDTH, _
        FILEDIALOG_ACTION_HEIGHT, @filedialog_OnCancel _
    )
    gui_AddGeneratedWidget(d->btn_cancel)
    gui_SetParent(d->btn_cancel, d->win)

    filedialog_Refresh(root)
    gui_SetModalRoot(root)

    Return root
End Function

Function filedialog_GetSelectedFile(ByVal w As Widget Ptr) As String
    If w = 0 Then Return ""
    Dim As FileDialogData Ptr d = w->data
    If d->finished = 1 Then Return d->selected_file
    Return ""
End Function

Function filedialog_GetResultState(ByVal w As Widget Ptr) As Integer
    If w = 0 Then Return 0
    Dim As FileDialogData Ptr d = w->data
    Return d->finished
End Function

/' end of filedialog.bas '/

/'
    Project: omaGUI
    ---------------

    File: test_filedialog.bas

    Purpose:

        Verify open, save, cancel, and modal file-dialog behavior.

    Responsibilities:

        - confirm dialogs enumerate the requested directory
        - exercise cancel, open, and save results through button input
        - verify removing a completed dialog clears modal state

    This file intentionally does NOT contain:

        - platform-native file dialogs
        - file creation or deletion
        - application-specific overwrite policy
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Const FILE_DIALOG_TEST_WIDTH As Integer = 800
Const FILE_DIALOG_TEST_HEIGHT As Integer = 600
Const FILE_DIALOG_TEST_X As Integer = 50
Const FILE_DIALOG_TEST_Y As Integer = 40
Const FILE_DIALOG_TEST_OPEN_X As Integer = FILE_DIALOG_TEST_X + 220 + 4
Const FILE_DIALOG_TEST_CANCEL_X As Integer = FILE_DIALOG_TEST_X + 310 + 4
Const FILE_DIALOG_TEST_BUTTON_Y As Integer = FILE_DIALOG_TEST_Y + 292 + 4

Sub fileDialogTest_Fail(ByVal messageText As String, ByVal exitCode As Integer)
    Print "file dialog test failed: "; messageText
    backend_Exit()
    End exitCode
End Sub

Sub fileDialogTest_Click(ByVal x As Integer, ByVal y As Integer)
    input_MockMouse x, y, 1
    gui_UpdateAll()
    input_MockMouse x, y, 0
    gui_UpdateAll()
End Sub

Dim As Widget Ptr dialogWidget
Dim As FileDialogData Ptr dialogData
Dim As ListBoxData Ptr listData
Dim As Integer selectedFileIndex
Dim As String selectedFilename

backend_Init FILE_DIALOG_TEST_WIDTH, FILE_DIALOG_TEST_HEIGHT, 1
gui_Init()

dialogWidget = filedialog_CreateAtPath( _
    "file_dialog_cancel", FILE_DIALOG_TEST_X, FILE_DIALOG_TEST_Y, CurDir _
)
gui_AddWidget dialogWidget
gui_UpdateAll()

If dialogWidget = 0 OrElse gui_IsModalOpen() = 0 Then
    fileDialogTest_Fail "open dialog was not created as modal", 1
End If

dialogData = Cast(FileDialogData Ptr, dialogWidget->data)
listData = Cast(ListBoxData Ptr, dialogData->lst->data)

If listData->item_count <= 0 OrElse listData->items(0) <> ".." Then
    fileDialogTest_Fail "directory list was not initialized", 2
End If

fileDialogTest_Click FILE_DIALOG_TEST_CANCEL_X, FILE_DIALOG_TEST_BUTTON_Y

If filedialog_GetResultState(dialogWidget) <> -1 Then
    fileDialogTest_Fail "cancel did not report a cancelled result", 3
End If

gui_RemoveWidget "file_dialog_cancel"

If gui_IsModalOpen() <> 0 Then
    fileDialogTest_Fail "removing the cancel dialog left modal state active", 4
End If

dialogWidget = filedialog_CreateSaveAtPath( _
    "file_dialog_save", FILE_DIALOG_TEST_X, FILE_DIALOG_TEST_Y, _
    CurDir, "saved_test.bas" _
)
gui_AddWidget dialogWidget
gui_UpdateAll()
fileDialogTest_Click FILE_DIALOG_TEST_OPEN_X, FILE_DIALOG_TEST_BUTTON_Y

If filedialog_GetResultState(dialogWidget) <> 1 OrElse _
   Right(filedialog_GetSelectedFile(dialogWidget), Len("saved_test.bas")) <> _
   "saved_test.bas" Then
    fileDialogTest_Fail "save did not return the requested filename", 5
End If

gui_RemoveWidget "file_dialog_save"

dialogWidget = filedialog_CreateAtPath( _
    "file_dialog_open", FILE_DIALOG_TEST_X, FILE_DIALOG_TEST_Y, CurDir _
)
gui_AddWidget dialogWidget
gui_UpdateAll()
dialogData = Cast(FileDialogData Ptr, dialogWidget->data)
listData = Cast(ListBoxData Ptr, dialogData->lst->data)
selectedFileIndex = -1
selectedFilename = ""

For itemIndex As Integer = 0 To listData->item_count - 1
    If listData->items(itemIndex) <> ".." AndAlso _
       Left(listData->items(itemIndex), 1) <> "[" Then
        selectedFileIndex = itemIndex
        selectedFilename = listData->items(itemIndex)
        Exit For
    End If
Next itemIndex

If selectedFileIndex < 0 Then
    fileDialogTest_Fail "the requested directory exposed no selectable file", 6
End If

listData->selected_index = selectedFileIndex
fileDialogTest_Click FILE_DIALOG_TEST_OPEN_X, FILE_DIALOG_TEST_BUTTON_Y

If filedialog_GetResultState(dialogWidget) <> 1 OrElse _
   Right(LCase(filedialog_GetSelectedFile(dialogWidget)), _
       Len(selectedFilename)) <> LCase(selectedFilename) Then
    fileDialogTest_Fail "open did not return the selected file", 7
End If

gui_RemoveWidget "file_dialog_open"
backend_Exit()
Print "file dialog test OK"
End 0

/' end of test_filedialog.bas '/

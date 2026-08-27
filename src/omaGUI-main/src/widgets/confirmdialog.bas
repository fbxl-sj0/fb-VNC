/'
    Project: omaGUI
    ---------------

    File: confirmdialog.bas

    Purpose:

        Implement a generated-widget modal confirmation window.

    Responsibilities:

        - own the generated subwindow, label, and action buttons
        - report accept or cancel without performing the application action
        - keep input inside the confirmation window while it is active

    This file intentionally does NOT contain:

        - application state mutation
        - file operations
        - platform-native dialog calls
'/

#lang "fb"

#include once "src/widgets/confirmdialog.bi"
#include once "src/widgets/subwindow.bi"
#include once "src/widgets/button.bi"
#include once "src/widgets/label.bi"

Type ConfirmDialogData
    As Widget Ptr windowWidget
    As Widget Ptr messageLabel
    As Widget Ptr confirmButton
    As Widget Ptr cancelButton
    As Integer finished
End Type

Private Sub confirmdialog_Destroy(ByVal w As Widget Ptr)
    If w->data <> 0 Then Delete Cast(ConfirmDialogData Ptr, w->data)
End Sub


Private Function confirmdialog_GetRoot(ByVal w As Widget Ptr) As Widget Ptr

    Dim As Widget Ptr current = w

    While current <> 0
        If current->parent = 0 Then Return current
        current = current->parent
    Wend

    Return 0

End Function


Private Sub confirmdialog_OnConfirm(ByVal w As Widget Ptr)

    Dim As Widget Ptr root = confirmdialog_GetRoot(w)

    If root <> 0 Then
        Cast(ConfirmDialogData Ptr, root->data)->finished = 1
    End If

End Sub


Private Sub confirmdialog_OnCancel(ByVal w As Widget Ptr)

    Dim As Widget Ptr root = confirmdialog_GetRoot(w)

    If root <> 0 Then
        Cast(ConfirmDialogData Ptr, root->data)->finished = -1
    End If

End Sub


Function confirmdialog_Create( _
    ByVal nm As String, _
    ByVal title As String, _
    ByVal message As String, _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal confirmText As String _
) As Widget Ptr

    Const CONFIRM_DIALOG_WIDTH = 400
    Const CONFIRM_DIALOG_HEIGHT = 150
    Const CONFIRM_DIALOG_BUTTON_WIDTH = 88
    Const CONFIRM_DIALOG_BUTTON_HEIGHT = 28

    Dim As Widget Ptr root = New Widget
    Dim As ConfirmDialogData Ptr dialogData = New ConfirmDialogData

    confirmText = Trim(confirmText)
    If confirmText = "" Then confirmText = "Discard"

    root->name = nm
    root->x = x
    root->y = y
    root->w = 0
    root->h = 0
    root->visible = 1
    root->enabled = 1
    root->ax = x
    root->ay = y
    root->evis = 1
    root->een = 1
    root->parent = 0
    root->next_widget = 0
    root->update = 0
    root->render = 0
    root->destroy = @confirmdialog_Destroy
    root->updated_this_frame = 0
    root->data = dialogData

    dialogData->finished = 0
    dialogData->windowWidget = subwindow_Create(nm & "_window", title, 0, 0, CONFIRM_DIALOG_WIDTH, CONFIRM_DIALOG_HEIGHT)
    subwindow_SetCloseHandler _
        dialogData->windowWidget, @confirmdialog_OnCancel
    dialogData->messageLabel = label_Create(nm & "_message", message, 16, 38)
    dialogData->confirmButton = button_Create(nm & "_confirm", confirmText, 200, 104, CONFIRM_DIALOG_BUTTON_WIDTH, CONFIRM_DIALOG_BUTTON_HEIGHT, @confirmdialog_OnConfirm)
    dialogData->cancelButton = button_Create(nm & "_cancel", "Cancel", 296, 104, CONFIRM_DIALOG_BUTTON_WIDTH, CONFIRM_DIALOG_BUTTON_HEIGHT, @confirmdialog_OnCancel)

    gui_AddGeneratedWidget(dialogData->windowWidget)
    gui_AddGeneratedWidget(dialogData->messageLabel)
    gui_AddGeneratedWidget(dialogData->confirmButton)
    gui_AddGeneratedWidget(dialogData->cancelButton)

    gui_SetParent(dialogData->windowWidget, root)
    gui_SetParent(dialogData->messageLabel, dialogData->windowWidget)
    gui_SetParent(dialogData->confirmButton, dialogData->windowWidget)
    gui_SetParent(dialogData->cancelButton, dialogData->windowWidget)
    gui_SetModalRoot(root)

    Return root

End Function


Function confirmdialog_GetResultState(ByVal w As Widget Ptr) As Integer

    If w = 0 Then Return 0
    Return Cast(ConfirmDialogData Ptr, w->data)->finished

End Function

' end of confirmdialog.bas

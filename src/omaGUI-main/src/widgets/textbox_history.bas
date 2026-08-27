/'
    Project: omaGUI
    ---------------

    File: textbox_history.bas

    Purpose:

        Provide bounded per-widget Undo and Redo for editable textboxes.

    Responsibilities:

        - snapshot text, cursor, selection, and scroll state before edits
        - coalesce related typing and deletion transactions
        - discard stale Redo state after a divergent edit
        - bound retained text by entry count and aggregate bytes
        - reset history when a textbox begins editing another document

    This file intentionally does NOT contain:

        - keyboard polling
        - textbox rendering
        - clipboard access
        - application-specific source validation
'/

#lang "fb"

#include once "src/widgets/textbox.bi"

' -------------------------------------------------------------------------
' Entry ownership helpers
' -------------------------------------------------------------------------

Private Sub textboxHistory_ClearEntry(ByRef entryData As TextBoxHistoryEntry)

    entryData.text = ""
    entryData.cursor_pos = 0
    entryData.sel_start = 0
    entryData.sel_end = 0
    entryData.selection_anchor = 0
    entryData.scroll_offset = 0
    entryData.v_scroll = 0

End Sub


Private Sub textboxHistory_Capture( _
    ByRef textData As TextBoxData, _
    ByRef entryData As TextBoxHistoryEntry _
)

    entryData.text = textData.text
    entryData.cursor_pos = textData.cursor_pos
    entryData.sel_start = textData.sel_start
    entryData.sel_end = textData.sel_end
    entryData.selection_anchor = textData.selection_anchor
    entryData.scroll_offset = textData.scroll_offset
    entryData.v_scroll = textData.v_scroll

End Sub


Private Function textboxHistory_ClampPosition( _
    ByRef textValue As String, _
    ByVal position As Integer _
) As Integer

    If position < 0 Then Return 0
    If position > Len(textValue) Then Return Len(textValue)

    Return position

End Function


Private Sub textboxHistory_Restore( _
    ByRef textData As TextBoxData, _
    ByRef entryData As TextBoxHistoryEntry _
)

    textData.text = entryData.text
    textData.cursor_pos = textboxHistory_ClampPosition( _
        textData.text, entryData.cursor_pos _
    )
    textData.sel_start = textboxHistory_ClampPosition( _
        textData.text, entryData.sel_start _
    )
    textData.sel_end = textboxHistory_ClampPosition( _
        textData.text, entryData.sel_end _
    )
    textData.selection_anchor = textboxHistory_ClampPosition( _
        textData.text, entryData.selection_anchor _
    )
    textData.scroll_offset = entryData.scroll_offset
    textData.v_scroll = entryData.v_scroll

    If textData.scroll_offset < 0 Then textData.scroll_offset = 0
    If textData.v_scroll < 0 Then textData.v_scroll = 0

End Sub

' -------------------------------------------------------------------------
' Bounded stack helpers
' -------------------------------------------------------------------------

Private Sub textboxHistory_ClearUndo(ByRef textData As TextBoxData)

    For entryIndex As Integer = 0 To textData.undoCount - 1
        textData.historyStoredBytes -= _
            Len(textData.undoEntries(entryIndex).text)
        textboxHistory_ClearEntry textData.undoEntries(entryIndex)
    Next entryIndex

    textData.undoCount = 0

End Sub


Private Sub textboxHistory_ClearRedo(ByRef textData As TextBoxData)

    For entryIndex As Integer = 0 To textData.redoCount - 1
        textData.historyStoredBytes -= _
            Len(textData.redoEntries(entryIndex).text)
        textboxHistory_ClearEntry textData.redoEntries(entryIndex)
    Next entryIndex

    textData.redoCount = 0

End Sub


Private Sub textboxHistory_DropOldestUndo(ByRef textData As TextBoxData)

    If textData.undoCount <= 0 Then Exit Sub

    textData.historyStoredBytes -= Len(textData.undoEntries(0).text)

    For entryIndex As Integer = 1 To textData.undoCount - 1
        textData.undoEntries(entryIndex - 1) = _
            textData.undoEntries(entryIndex)
    Next entryIndex

    textData.undoCount -= 1
    textboxHistory_ClearEntry textData.undoEntries(textData.undoCount)

End Sub


Private Sub textboxHistory_DropOldestRedo(ByRef textData As TextBoxData)

    If textData.redoCount <= 0 Then Exit Sub

    textData.historyStoredBytes -= Len(textData.redoEntries(0).text)

    For entryIndex As Integer = 1 To textData.redoCount - 1
        textData.redoEntries(entryIndex - 1) = _
            textData.redoEntries(entryIndex)
    Next entryIndex

    textData.redoCount -= 1
    textboxHistory_ClearEntry textData.redoEntries(textData.redoCount)

End Sub


Private Function textboxHistory_MakeRoom( _
    ByRef textData As TextBoxData, _
    ByVal byteCount As LongInt _
) As Integer

    If byteCount < 0 OrElse _
       byteCount > TEXTBOX_HISTORY_MAX_STORED_BYTES Then
        Return 0
    End If

    Do While textData.historyStoredBytes + byteCount > _
             TEXTBOX_HISTORY_MAX_STORED_BYTES
        If textData.undoCount > 0 Then
            textboxHistory_DropOldestUndo textData
        Elseif textData.redoCount > 0 Then
            textboxHistory_DropOldestRedo textData
        Else
            Return 0
        End If
    Loop

    Return 1

End Function


Private Function textboxHistory_PushUndo( _
    ByRef textData As TextBoxData, _
    ByRef entryData As TextBoxHistoryEntry _
) As Integer

    If textData.undoCount >= TEXTBOX_HISTORY_MAX_ENTRIES Then _
        textboxHistory_DropOldestUndo textData

    If textboxHistory_MakeRoom(textData, Len(entryData.text)) = 0 Then _
        Return 0

    textData.undoEntries(textData.undoCount) = entryData
    textData.undoCount += 1
    textData.historyStoredBytes += Len(entryData.text)

    Return 1

End Function


Private Function textboxHistory_PushRedo( _
    ByRef textData As TextBoxData, _
    ByRef entryData As TextBoxHistoryEntry _
) As Integer

    If textData.redoCount >= TEXTBOX_HISTORY_MAX_ENTRIES Then _
        textboxHistory_DropOldestRedo textData

    If textboxHistory_MakeRoom(textData, Len(entryData.text)) = 0 Then _
        Return 0

    textData.redoEntries(textData.redoCount) = entryData
    textData.redoCount += 1
    textData.historyStoredBytes += Len(entryData.text)

    Return 1

End Function

' -------------------------------------------------------------------------
' Public history API
' -------------------------------------------------------------------------

Sub textbox_ClearHistory(ByVal w As Widget Ptr)

    Dim textData As TextBoxData Ptr

    If w = 0 OrElse w->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, w->data)

    textboxHistory_ClearUndo *textData
    textboxHistory_ClearRedo *textData
    textData->historyStoredBytes = 0
    textData->historyGroup = TEXTBOX_HISTORY_GROUP_NONE
    textData->historyIdleFrames = 0

End Sub


Function textbox_BeginEdit( _
    ByVal w As Widget Ptr, _
    ByVal groupId As Integer _
) As Integer

    Dim entryData As TextBoxHistoryEntry
    Dim textData As TextBoxData Ptr

    textbox_BeginEdit = 0

    If w = 0 OrElse w->data = 0 Then Exit Function
    textData = Cast(TextBoxData Ptr, w->data)

    If groupId < TEXTBOX_HISTORY_GROUP_NONE Then _
        groupId = TEXTBOX_HISTORY_GROUP_NONE

    If groupId > TEXTBOX_HISTORY_GROUP_NONE AndAlso _
       textData->historyGroup = groupId Then
        textData->historyIdleFrames = 0
        Return 1
    End If

    textboxHistory_Capture *textData, entryData
    textboxHistory_ClearRedo *textData

    If textboxHistory_PushUndo(*textData, entryData) = 0 Then
        textboxHistory_ClearUndo *textData
        textData->historyGroup = TEXTBOX_HISTORY_GROUP_NONE
        textData->historyIdleFrames = 0
        Exit Function
    End If

    textData->historyGroup = IIf( _
        groupId > TEXTBOX_HISTORY_GROUP_NONE, _
        groupId, TEXTBOX_HISTORY_GROUP_NONE _
    )
    textData->historyIdleFrames = 0

    Return 1

End Function


Sub textbox_EndEditGroup(ByVal w As Widget Ptr)

    Dim textData As TextBoxData Ptr

    If w = 0 OrElse w->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, w->data)
    textData->historyGroup = TEXTBOX_HISTORY_GROUP_NONE
    textData->historyIdleFrames = 0

End Sub


Function textbox_Undo(ByVal w As Widget Ptr) As Integer

    Dim currentEntry As TextBoxHistoryEntry
    Dim targetEntry As TextBoxHistoryEntry
    Dim textData As TextBoxData Ptr

    textbox_Undo = 0

    If w = 0 OrElse w->data = 0 Then Exit Function
    textData = Cast(TextBoxData Ptr, w->data)

    If textData->undoCount <= 0 OrElse _
       Len(textData->text) > TEXTBOX_HISTORY_MAX_STORED_BYTES Then
        Exit Function
    End If

    textboxHistory_Capture *textData, currentEntry
    targetEntry = textData->undoEntries(textData->undoCount - 1)
    textData->historyStoredBytes -= Len(targetEntry.text)
    textData->undoCount -= 1
    textboxHistory_ClearEntry textData->undoEntries(textData->undoCount)

    If textboxHistory_PushRedo(*textData, currentEntry) = 0 Then
        textboxHistory_PushUndo *textData, targetEntry
        Exit Function
    End If

    textboxHistory_Restore *textData, targetEntry
    textData->historyGroup = TEXTBOX_HISTORY_GROUP_NONE
    textData->historyIdleFrames = 0

    Return 1

End Function


Function textbox_Redo(ByVal w As Widget Ptr) As Integer

    Dim currentEntry As TextBoxHistoryEntry
    Dim targetEntry As TextBoxHistoryEntry
    Dim textData As TextBoxData Ptr

    textbox_Redo = 0

    If w = 0 OrElse w->data = 0 Then Exit Function
    textData = Cast(TextBoxData Ptr, w->data)

    If textData->redoCount <= 0 OrElse _
       Len(textData->text) > TEXTBOX_HISTORY_MAX_STORED_BYTES Then
        Exit Function
    End If

    textboxHistory_Capture *textData, currentEntry
    targetEntry = textData->redoEntries(textData->redoCount - 1)
    textData->historyStoredBytes -= Len(targetEntry.text)
    textData->redoCount -= 1
    textboxHistory_ClearEntry textData->redoEntries(textData->redoCount)

    If textboxHistory_PushUndo(*textData, currentEntry) = 0 Then
        textboxHistory_PushRedo *textData, targetEntry
        Exit Function
    End If

    textboxHistory_Restore *textData, targetEntry
    textData->historyGroup = TEXTBOX_HISTORY_GROUP_NONE
    textData->historyIdleFrames = 0

    Return 1

End Function


Function textbox_SetText( _
    ByVal w As Widget Ptr, _
    ByVal textValue As String, _
    ByVal resetHistory As Integer _
) As Integer

    Dim textData As TextBoxData Ptr

    textbox_SetText = 0

    If w = 0 OrElse w->data = 0 Then Exit Function
    textData = Cast(TextBoxData Ptr, w->data)

    If resetHistory = 0 AndAlso textData->text <> textValue Then _
        textbox_BeginEdit w, TEXTBOX_HISTORY_GROUP_NONE

    textData->text = textValue
    textData->cursor_pos = Len(textData->text)
    textData->sel_start = textData->cursor_pos
    textData->sel_end = textData->cursor_pos
    textData->selection_anchor = textData->cursor_pos
    textData->scroll_offset = 0
    textData->v_scroll = 0
    textData->viewport_dirty = -1

    If resetHistory <> 0 Then textbox_ClearHistory w

    Return 1

End Function

' end of textbox_history.bas

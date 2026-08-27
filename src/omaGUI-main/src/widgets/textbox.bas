/'
    Project: omaGUI
    ---------------

    File: textbox.bas

    Purpose:

        Implement a reusable text editor widget for both compact controls and
        multiline authoring surfaces such as the JRPG object-script popup.

    Responsibilities:

        - insert and remove text at the active cursor position
        - place the cursor and select text with mouse or keyboard input
        - provide selection-aware Cut, Copy, Paste, and Select All commands
        - route Ctrl+Z and Ctrl+Y to the textbox's local history
        - navigate logical lines with arrow, home, and end keys
        - keep the active cursor within the visible viewport
        - render and operate an optional multiline vertical scrollbar
        - use one visual-line model for wrapping, scrolling, and hit testing

    This file intentionally does NOT contain:

        - syntax highlighting
        - application-specific text validation
        - platform clipboard implementation
'/

#lang "fb"

#include once "src/widgets/textbox.bi"
#include once "src/widgets/menu.bi"
#include once "src/widgets/scrollbar.bi"
#include once "src/backend/clipboard.bi"
#include once "src/backend/theme.bi"

' -------------------------------------------------------------------------
' Text editing constants
' -------------------------------------------------------------------------

Const TEXTBOX_LINE_HEIGHT As Integer = 14
Const TEXTBOX_LINE_FEED As Integer = 10
Const TEXTBOX_CARRIAGE_RETURN As Integer = 13
Const TEXTBOX_TEXT_LEFT_PADDING As Integer = 5
Const TEXTBOX_TEXT_RIGHT_PADDING As Integer = 10
Const TEXTBOX_TEXT_BOTTOM_PADDING As Integer = 15
Const TEXTBOX_KEY_LATCH_BACKSPACE As Integer = 1
Const TEXTBOX_KEY_LATCH_DELETE As Integer = 2
Const TEXTBOX_KEY_LATCH_RETURN As Integer = 4
Const TEXTBOX_KEY_LATCH_LEFT As Integer = 8
Const TEXTBOX_KEY_LATCH_RIGHT As Integer = 16
Const TEXTBOX_KEY_LATCH_HOME As Integer = 32
Const TEXTBOX_KEY_LATCH_END As Integer = 64
Const TEXTBOX_KEY_LATCH_UP As Integer = 128
Const TEXTBOX_KEY_LATCH_DOWN As Integer = 256
Const TEXTBOX_KEY_LATCH_UNDO As Integer = 512
Const TEXTBOX_KEY_LATCH_REDO As Integer = 1024
Const TEXTBOX_KEY_LATCH_SELECT_ALL As Integer = 2048
Const TEXTBOX_KEY_LATCH_COPY As Integer = 4096
Const TEXTBOX_KEY_LATCH_CUT As Integer = 8192
Const TEXTBOX_KEY_LATCH_PASTE As Integer = 16384
Const TEXTBOX_HISTORY_IDLE_FRAME_LIMIT As Integer = 30
Const TEXTBOX_CURSOR_VISIBLE_WIDTH As Integer = 2
Const TEXTBOX_SCROLLBAR_WIDTH As Integer = 15
Const TEXTBOX_SCROLLBAR_INSET As Integer = 2
Const TEXTBOX_WHEEL_LINES As Integer = 3

' -------------------------------------------------------------------------
' Shared widget state
' -------------------------------------------------------------------------

Dim Shared As Widget Ptr textbox_context_menu = 0
Dim Shared As Widget Ptr active_textbox = 0

' -------------------------------------------------------------------------
' Internal helpers
' -------------------------------------------------------------------------

Declare Function textbox_ClampPosition(ByVal textValue As String, ByVal position As Integer) As Integer
Declare Sub textbox_CollapseSelection(ByVal textData As TextBoxData Ptr, ByVal position As Integer)
Declare Sub textbox_ExtendSelection(ByVal textData As TextBoxData Ptr, ByVal position As Integer)
Declare Sub textbox_DeleteSelection(ByVal textData As TextBoxData Ptr)
Declare Function textbox_SelectedText(ByVal textData As TextBoxData Ptr) As String
Declare Sub textbox_InsertText(ByVal textData As TextBoxData Ptr, ByVal insertedText As String)
Declare Sub textbox_ClearKeyLatch(ByVal textData As TextBoxData Ptr, ByVal keyCode As Integer, ByVal keyMask As Integer)
Declare Sub textbox_RefreshKeyLatch(ByVal textData As TextBoxData Ptr)
Declare Function textbox_KeyJustPressed(ByVal textData As TextBoxData Ptr, ByVal keyCode As Integer, ByVal keyMask As Integer) As Integer
Declare Function textbox_LineStart(ByVal textValue As String, ByVal position As Integer) As Integer
Declare Function textbox_LineEnd(ByVal textValue As String, ByVal position As Integer) As Integer
Declare Function textbox_LineStartByIndex( _
    ByVal textValue As String, _
    ByVal lineIndex As Integer _
) As Integer
Declare Function textbox_NextVisualLine( _
    ByVal textValue As String, _
    ByRef scanPosition As Integer, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer, _
    ByRef lineStart As Integer, _
    ByRef lineEnd As Integer _
) As Integer
Declare Function textbox_CountVisualLines( _
    ByVal textValue As String, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer _
) As Integer
Declare Function textbox_VisualLineForPosition( _
    ByVal textValue As String, _
    ByVal position As Integer, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer _
) As Integer
Declare Function textbox_VisualLineBounds( _
    ByVal textValue As String, _
    ByVal targetLine As Integer, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer, _
    ByRef lineStart As Integer, _
    ByRef lineEnd As Integer _
) As Integer
Declare Function textbox_VisibleLineCount(ByVal w As Widget Ptr) As Integer
Declare Function textbox_ContentWidth( _
    ByVal w As Widget Ptr, ByVal textData As TextBoxData Ptr _
) As Integer
Declare Sub textbox_UpdateScrollMetrics( _
    ByVal w As Widget Ptr, ByVal textData As TextBoxData Ptr _
)
Declare Function textbox_PointInScrollbar( _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, ByVal mouseY As Integer _
) As Integer
Declare Function textbox_HandleScrollInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, _
    ByVal mouseY As Integer, _
    ByVal mouseButtons As Integer _
) As Integer
Declare Function textbox_PositionFromPoint( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, _
    ByVal mouseY As Integer _
) As Integer
Declare Function textbox_ShiftPressed() As Integer
Declare Sub textbox_MoveCursorVertical( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal direction As Integer, _
    ByVal extendSelection As Integer _
)
Declare Function textbox_LineForPosition(ByVal textValue As String, ByVal position As Integer) As Integer
Declare Sub textbox_EnsureCursorVisible(ByVal w As Widget Ptr, ByVal textData As TextBoxData Ptr)
Declare Sub textbox_RenderLine( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal lineIndex As Integer, _
    ByVal lineStart As Integer, _
    ByVal lineText As String _
)
Declare Sub textbox_HandleDeletionInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr _
)
Declare Sub textbox_HandleNavigationInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr _
)
Declare Sub textbox_HandleMouseInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, _
    ByVal mouseY As Integer, _
    ByVal mouseButtons As Integer _
)
Declare Function textbox_HandleControlInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr _
) As Integer


Private Function textbox_ClampPosition(ByVal textValue As String, ByVal position As Integer) As Integer

    If position < 0 Then Return 0
    If position > Len(textValue) Then Return Len(textValue)
    Return position

End Function


Private Function textbox_NextVisualLine( _
    ByVal textValue As String, _
    ByRef scanPosition As Integer, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer, _
    ByRef lineStart As Integer, _
    ByRef lineEnd As Integer _
) As Integer
    Dim As Integer characterWidth
    Dim As Integer ch
    Dim As Integer lastSpace = -1
    Dim As Integer lineWidth
    Dim As Integer position
    Dim As Integer textLength = Len(textValue)

    If scanPosition < 0 Then scanPosition = 0
    If scanPosition > textLength Then Return 0
    If contentWidth < 1 Then contentWidth = 1

    lineStart = scanPosition

    /'
        A scan positioned exactly at the end represents the final empty row of
        an empty string or a string ending in a newline. Advancing past the end
        guarantees that every successful call makes progress.
    '/
    If scanPosition = textLength Then
        lineEnd = textLength
        scanPosition = textLength + 1
        Return -1
    End If

    position = scanPosition
    While position < textLength
        ch = textValue[position]

        If ch = TEXTBOX_LINE_FEED OrElse _
           ch = TEXTBOX_CARRIAGE_RETURN Then
            lineEnd = position
            scanPosition = position + 1

            If ch = TEXTBOX_CARRIAGE_RETURN AndAlso _
               scanPosition < textLength AndAlso _
               textValue[scanPosition] = TEXTBOX_LINE_FEED Then
                scanPosition += 1
            End If

            Return -1
        End If

        characterWidth = backend_GetTextWidth( _
            Mid(textValue, position + 1, 1) _
        )
        lineWidth += characterWidth

        If ch = Asc(" ") Then lastSpace = position

        If wordwrap <> 0 AndAlso lineWidth > contentWidth Then
            If lastSpace >= lineStart Then
                lineEnd = lastSpace
                scanPosition = lastSpace + 1
            ElseIf position > lineStart Then
                lineEnd = position
                scanPosition = position
            Else
                /'
                    A single glyph can be wider than a very narrow widget.
                    Keep it on one row instead of emitting an empty row and
                    repeating the same scan position forever.
                '/
                lineEnd = position + 1
                scanPosition = position + 1
            End If

            Return -1
        End If

        position += 1
    Wend

    lineEnd = textLength
    scanPosition = textLength + 1
    Return -1
End Function


Private Function textbox_CountVisualLines( _
    ByVal textValue As String, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer _
) As Integer
    Dim As Integer lineEnd
    Dim As Integer lineStart
    Dim As Integer scanPosition
    Dim As Integer visualLines

    While textbox_NextVisualLine( _
        textValue, scanPosition, wordwrap, contentWidth, _
        lineStart, lineEnd _
    )
        visualLines += 1
    Wend

    If visualLines < 1 Then visualLines = 1
    Return visualLines
End Function


Private Function textbox_VisualLineForPosition( _
    ByVal textValue As String, _
    ByVal position As Integer, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer _
) As Integer
    Dim As Integer lineEnd
    Dim As Integer lineIndex
    Dim As Integer lineStart
    Dim As Integer scanPosition

    position = textbox_ClampPosition(textValue, position)

    While textbox_NextVisualLine( _
        textValue, scanPosition, wordwrap, contentWidth, _
        lineStart, lineEnd _
    )
        If position <= lineEnd Then Return lineIndex
        lineIndex += 1
    Wend

    If lineIndex > 0 Then Return lineIndex - 1
    Return 0
End Function


Private Function textbox_VisualLineBounds( _
    ByVal textValue As String, _
    ByVal targetLine As Integer, _
    ByVal wordwrap As Integer, _
    ByVal contentWidth As Integer, _
    ByRef lineStart As Integer, _
    ByRef lineEnd As Integer _
) As Integer
    Dim As Integer lineIndex
    Dim As Integer scanPosition

    If targetLine < 0 Then targetLine = 0

    While textbox_NextVisualLine( _
        textValue, scanPosition, wordwrap, contentWidth, _
        lineStart, lineEnd _
    )
        If lineIndex = targetLine Then Return -1
        lineIndex += 1
    Wend

    Return 0
End Function


Private Function textbox_VisibleLineCount(ByVal w As Widget Ptr) As Integer
    Dim As Integer visibleLines

    If w = 0 Then Return 1

    visibleLines = (w->h - TEXTBOX_TEXT_BOTTOM_PADDING) \ _
        TEXTBOX_LINE_HEIGHT
    If visibleLines < 1 Then visibleLines = 1
    Return visibleLines
End Function


Private Function textbox_ContentWidth( _
    ByVal w As Widget Ptr, ByVal textData As TextBoxData Ptr _
) As Integer
    Dim As Integer contentWidth

    If w = 0 Then Return 1

    contentWidth = w->w - TEXTBOX_TEXT_LEFT_PADDING - _
        TEXTBOX_TEXT_RIGHT_PADDING

    If textData <> 0 AndAlso textData->scrollbar_visible <> 0 Then
        contentWidth -= TEXTBOX_SCROLLBAR_WIDTH + TEXTBOX_SCROLLBAR_INSET
    End If

    If contentWidth < 1 Then contentWidth = 1
    Return contentWidth
End Function


Private Sub textbox_UpdateScrollMetrics( _
    ByVal w As Widget Ptr, ByVal textData As TextBoxData Ptr _
)
    Dim As Integer contentWidth
    Dim As Integer maximumScroll
    Dim As Integer mode
    Dim As ScrollBarData Ptr scrollData
    Dim As Integer unreservedWidth
    Dim As Integer visibleLines

    If w = 0 OrElse textData = 0 Then Exit Sub

    mode = textData->scrollbar_mode
    If mode < TEXTBOX_SCROLLBAR_NONE OrElse _
       mode > TEXTBOX_SCROLLBAR_ALWAYS Then
        mode = TEXTBOX_SCROLLBAR_AUTO
        textData->scrollbar_mode = mode
    End If

    visibleLines = textbox_VisibleLineCount(w)
    unreservedWidth = w->w - TEXTBOX_TEXT_LEFT_PADDING - _
        TEXTBOX_TEXT_RIGHT_PADDING
    If unreservedWidth < 1 Then unreservedWidth = 1

    textData->scrollbar_visible = 0

    If textData->multiline <> 0 Then
        Select Case mode
        Case TEXTBOX_SCROLLBAR_ALWAYS
            textData->scrollbar_visible = -1
        Case TEXTBOX_SCROLLBAR_AUTO
            If textbox_CountVisualLines( _
                textData->text, textData->wordwrap, unreservedWidth _
            ) > visibleLines Then
                textData->scrollbar_visible = -1
            End If
        Case Else
            textData->scrollbar_visible = 0
        End Select
    End If

    contentWidth = textbox_ContentWidth(w, textData)
    textData->total_visual_lines = textbox_CountVisualLines( _
        textData->text, textData->wordwrap, contentWidth _
    )
    maximumScroll = textData->total_visual_lines - visibleLines
    If maximumScroll < 0 Then maximumScroll = 0

    If textData->v_scroll < 0 Then textData->v_scroll = 0
    If textData->v_scroll > maximumScroll Then _
        textData->v_scroll = maximumScroll

    If textData->vertical_scrollbar = 0 OrElse _
       textData->vertical_scrollbar->data = 0 Then
        Exit Sub
    End If

    textData->vertical_scrollbar->ax = w->ax + w->w - _
        TEXTBOX_SCROLLBAR_WIDTH - TEXTBOX_SCROLLBAR_INSET
    textData->vertical_scrollbar->ay = w->ay + TEXTBOX_SCROLLBAR_INSET
    textData->vertical_scrollbar->w = TEXTBOX_SCROLLBAR_WIDTH
    textData->vertical_scrollbar->h = w->h - _
        (TEXTBOX_SCROLLBAR_INSET * 2)

    If textData->vertical_scrollbar->h < 1 Then _
        textData->vertical_scrollbar->h = 1

    scrollData = Cast( _
        ScrollBarData Ptr, textData->vertical_scrollbar->data _
    )
    scrollData->value = textData->v_scroll
    scrollData->max_val = maximumScroll
    scrollData->page_size = visibleLines
    scrollData->vertical = -1
    textData->vertical_scrollbar->enabled = IIf(maximumScroll > 0, -1, 0)
End Sub


Private Function textbox_PointInScrollbar( _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, ByVal mouseY As Integer _
) As Integer
    Dim As Widget Ptr scrollWidget

    If textData = 0 OrElse textData->scrollbar_visible = 0 Then Return 0
    scrollWidget = textData->vertical_scrollbar
    If scrollWidget = 0 Then Return 0

    Return IIf( _
        mouseX >= scrollWidget->ax AndAlso _
        mouseX < scrollWidget->ax + scrollWidget->w AndAlso _
        mouseY >= scrollWidget->ay AndAlso _
        mouseY < scrollWidget->ay + scrollWidget->h, _
        1, 0 _
    )
End Function


Private Function textbox_HandleScrollInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, _
    ByVal mouseY As Integer, _
    ByVal mouseButtons As Integer _
) As Integer
    Dim As Integer insideWidget
    Dim As Integer maximumScroll
    Dim As ScrollBarData Ptr scrollData
    Dim As Widget Ptr scrollWidget
    Dim As Integer wheelDelta

    If w = 0 OrElse textData = 0 Then Return 0
    If textData->multiline = 0 Then Return 0

    insideWidget = IIf( _
        mouseX >= w->ax AndAlso mouseX < w->ax + w->w AndAlso _
        mouseY >= w->ay AndAlso mouseY < w->ay + w->h, _
        1, 0 _
    )
    maximumScroll = textData->total_visual_lines - _
        textbox_VisibleLineCount(w)
    If maximumScroll < 0 Then maximumScroll = 0

    wheelDelta = input_MouseWheel()
    If insideWidget <> 0 AndAlso wheelDelta <> 0 AndAlso _
       maximumScroll > 0 Then
        textData->v_scroll -= wheelDelta * TEXTBOX_WHEEL_LINES
        textbox_UpdateScrollMetrics w, textData
    End If

    scrollWidget = textData->vertical_scrollbar
    If scrollWidget = 0 OrElse scrollWidget->data = 0 OrElse _
       textData->scrollbar_visible = 0 Then
        textData->scrollbar_dragging = 0
        Return 0
    End If

    If (mouseButtons And 1) = 0 Then
        textData->scrollbar_dragging = 0
        Return 0
    End If

    If textData->scrollbar_dragging = 0 AndAlso _
       textbox_PointInScrollbar(textData, mouseX, mouseY) = 0 Then
        Return 0
    End If

    textData->scrollbar_dragging = -1
    textData->mouse_latch = 1
    textData->mouse_selecting = 0
    scrollData = Cast(ScrollBarData Ptr, scrollWidget->data)

    If maximumScroll > 0 AndAlso scrollWidget->h > 0 Then
        scrollData->value = _
            ((mouseY - scrollWidget->ay) * maximumScroll) \ _
            scrollWidget->h
        If scrollData->value < 0 Then scrollData->value = 0
        If scrollData->value > maximumScroll Then _
            scrollData->value = maximumScroll
        textData->v_scroll = scrollData->value
    End If

    Return 1
End Function


Private Sub textbox_CollapseSelection(ByVal textData As TextBoxData Ptr, ByVal position As Integer)

    If textData = 0 Then Exit Sub

    position = textbox_ClampPosition(textData->text, position)
    textData->cursor_pos = position
    textData->sel_start = position
    textData->sel_end = position
    textData->selection_anchor = position

End Sub


Private Sub textbox_ExtendSelection( _
    ByVal textData As TextBoxData Ptr, _
    ByVal position As Integer _
)

    If textData = 0 Then Exit Sub

    position = textbox_ClampPosition(textData->text, position)
    textData->selection_anchor = textbox_ClampPosition( _
        textData->text, textData->selection_anchor _
    )
    textData->cursor_pos = position

    If position < textData->selection_anchor Then
        textData->sel_start = position
        textData->sel_end = textData->selection_anchor
    Else
        textData->sel_start = textData->selection_anchor
        textData->sel_end = position
    End If

End Sub


Private Sub textbox_DeleteSelection(ByVal textData As TextBoxData Ptr)

    Dim startPosition As Integer
    Dim endPosition As Integer
    Dim swapPosition As Integer

    If textData = 0 Then Exit Sub

    startPosition = textbox_ClampPosition(textData->text, textData->sel_start)
    endPosition = textbox_ClampPosition(textData->text, textData->sel_end)

    If endPosition < startPosition Then
        swapPosition = startPosition
        startPosition = endPosition
        endPosition = swapPosition
    End If

    If startPosition = endPosition Then
        textbox_CollapseSelection textData, startPosition
        Exit Sub
    End If

    textData->text = Left(textData->text, startPosition) & Mid(textData->text, endPosition + 1)
    textbox_CollapseSelection textData, startPosition

End Sub


Private Function textbox_SelectedText( _
    ByVal textData As TextBoxData Ptr _
) As String

    Dim endPosition As Integer
    Dim startPosition As Integer

    If textData = 0 Then Return ""

    startPosition = textbox_ClampPosition( _
        textData->text, textData->sel_start _
    )
    endPosition = textbox_ClampPosition( _
        textData->text, textData->sel_end _
    )

    If endPosition < startPosition Then Swap startPosition, endPosition
    If endPosition <= startPosition Then Return ""

    Return Mid( _
        textData->text, startPosition + 1, endPosition - startPosition _
    )

End Function


Private Sub textbox_InsertText(ByVal textData As TextBoxData Ptr, ByVal insertedText As String)

    Dim position As Integer

    If textData = 0 OrElse insertedText = "" Then Exit Sub

    textbox_DeleteSelection textData
    position = textbox_ClampPosition(textData->text, textData->cursor_pos)
    textData->text = Left(textData->text, position) & insertedText & Mid(textData->text, position + 1)
    textbox_CollapseSelection textData, position + Len(insertedText)

End Sub


Private Sub textbox_ClearKeyLatch(ByVal textData As TextBoxData Ptr, ByVal keyCode As Integer, ByVal keyMask As Integer)

    If textData = 0 Then Exit Sub
    If input_KeyPressed(keyCode) <> 0 Then Exit Sub

    If (textData->key_latch And keyMask) <> 0 Then textData->key_latch -= keyMask

End Sub


Private Sub textbox_RefreshKeyLatch(ByVal textData As TextBoxData Ptr)

    If textData = 0 Then Exit Sub

    textbox_ClearKeyLatch textData, KEY_BACKSPACE, TEXTBOX_KEY_LATCH_BACKSPACE
    textbox_ClearKeyLatch textData, KEY_DELETE, TEXTBOX_KEY_LATCH_DELETE
    textbox_ClearKeyLatch textData, KEY_RETURN, TEXTBOX_KEY_LATCH_RETURN
    textbox_ClearKeyLatch textData, KEY_LEFT, TEXTBOX_KEY_LATCH_LEFT
    textbox_ClearKeyLatch textData, KEY_RIGHT, TEXTBOX_KEY_LATCH_RIGHT
    textbox_ClearKeyLatch textData, KEY_HOME, TEXTBOX_KEY_LATCH_HOME
    textbox_ClearKeyLatch textData, KEY_END, TEXTBOX_KEY_LATCH_END
    textbox_ClearKeyLatch textData, KEY_UP, TEXTBOX_KEY_LATCH_UP
    textbox_ClearKeyLatch textData, KEY_DOWN, TEXTBOX_KEY_LATCH_DOWN
    textbox_ClearKeyLatch textData, FB.SC_Z, TEXTBOX_KEY_LATCH_UNDO
    textbox_ClearKeyLatch textData, FB.SC_Y, TEXTBOX_KEY_LATCH_REDO
    textbox_ClearKeyLatch textData, FB.SC_A, TEXTBOX_KEY_LATCH_SELECT_ALL
    textbox_ClearKeyLatch textData, FB.SC_C, TEXTBOX_KEY_LATCH_COPY
    textbox_ClearKeyLatch textData, FB.SC_X, TEXTBOX_KEY_LATCH_CUT
    textbox_ClearKeyLatch textData, FB.SC_V, TEXTBOX_KEY_LATCH_PASTE

End Sub


Private Function textbox_KeyJustPressed(ByVal textData As TextBoxData Ptr, ByVal keyCode As Integer, ByVal keyMask As Integer) As Integer

    If textData = 0 Then Return 0
    If input_KeyPressed(keyCode) = 0 Then Return 0
    If (textData->key_latch And keyMask) <> 0 Then Return 0

    textData->key_latch Or= keyMask
    Return 1

End Function


Private Function textbox_LineStart(ByVal textValue As String, ByVal position As Integer) As Integer

    position = textbox_ClampPosition(textValue, position)

    While position > 0
        If textValue[position - 1] = TEXTBOX_LINE_FEED OrElse _
           textValue[position - 1] = TEXTBOX_CARRIAGE_RETURN Then
            Exit While
        End If
        position -= 1
    Wend

    Return position

End Function


Private Function textbox_LineEnd(ByVal textValue As String, ByVal position As Integer) As Integer

    position = textbox_ClampPosition(textValue, position)

    While position < Len(textValue)
        If textValue[position] = TEXTBOX_LINE_FEED OrElse _
           textValue[position] = TEXTBOX_CARRIAGE_RETURN Then
            Exit While
        End If
        position += 1
    Wend

    Return position

End Function


Private Function textbox_LineStartByIndex( _
    ByVal textValue As String, _
    ByVal lineIndex As Integer _
) As Integer

    Dim currentLine As Integer
    Dim position As Integer

    If lineIndex <= 0 Then Return 0

    While position < Len(textValue)
        If textValue[position] = TEXTBOX_LINE_FEED Then
            currentLine += 1
            position += 1
        Elseif textValue[position] = TEXTBOX_CARRIAGE_RETURN Then
            currentLine += 1
            position += 1

            If position < Len(textValue) AndAlso _
               textValue[position] = TEXTBOX_LINE_FEED Then
                position += 1
            End If
        Else
            position += 1
        End If

        If currentLine >= lineIndex Then Return position
    Wend

    Return Len(textValue)

End Function


Private Function textbox_PositionFromPoint( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, _
    ByVal mouseY As Integer _
) As Integer

    Dim characterWidth As Integer
    Dim lineEnd As Integer
    Dim contentWidth As Integer
    Dim lineIndex As Integer
    Dim lineStart As Integer
    Dim targetX As Integer
    Dim textWidth As Integer

    If w = 0 OrElse textData = 0 Then Return 0

    lineIndex = textData->v_scroll + _
        (mouseY - w->ay - TEXTBOX_TEXT_LEFT_PADDING) \ TEXTBOX_LINE_HEIGHT
    If lineIndex < 0 Then lineIndex = 0

    contentWidth = textbox_ContentWidth(w, textData)
    If textbox_VisualLineBounds( _
        textData->text, lineIndex, textData->wordwrap, contentWidth, _
        lineStart, lineEnd _
    ) = 0 Then
        Return Len(textData->text)
    End If
    targetX = mouseX - w->ax - TEXTBOX_TEXT_LEFT_PADDING

    If textData->wordwrap = 0 Then targetX += textData->scroll_offset
    If targetX <= 0 Then Return lineStart

    For position As Integer = lineStart To lineEnd - 1
        characterWidth = backend_GetTextWidth( _
            Mid(textData->text, position + 1, 1) _
        )

        If targetX < textWidth + (characterWidth + 1) \ 2 Then _
            Return position
        textWidth += characterWidth
    Next position

    Return lineEnd

End Function


Private Function textbox_ShiftPressed() As Integer

    Return IIf( _
        input_KeyPressed(FB.SC_LSHIFT) <> 0 OrElse _
        input_KeyPressed(FB.SC_RSHIFT) <> 0, _
        1, 0 _
    )

End Function


Private Sub textbox_MoveCursorVertical( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal direction As Integer, _
    ByVal extendSelection As Integer _
)

    Dim contentWidth As Integer
    Dim currentEnd As Integer
    Dim currentLine As Integer
    Dim currentStart As Integer
    Dim currentColumn As Integer
    Dim targetLine As Integer
    Dim targetPosition As Integer
    Dim targetStart As Integer
    Dim targetEnd As Integer

    If w = 0 OrElse textData = 0 OrElse direction = 0 Then Exit Sub

    textData->cursor_pos = textbox_ClampPosition(textData->text, textData->cursor_pos)
    contentWidth = textbox_ContentWidth(w, textData)
    currentLine = textbox_VisualLineForPosition( _
        textData->text, textData->cursor_pos, _
        textData->wordwrap, contentWidth _
    )
    targetLine = currentLine + direction
    If targetLine < 0 Then Exit Sub

    If textbox_VisualLineBounds( _
        textData->text, currentLine, textData->wordwrap, contentWidth, _
        currentStart, currentEnd _
    ) = 0 Then
        Exit Sub
    End If
    If textbox_VisualLineBounds( _
        textData->text, targetLine, textData->wordwrap, contentWidth, _
        targetStart, targetEnd _
    ) = 0 Then
        Exit Sub
    End If

    currentColumn = textData->cursor_pos - currentStart
    If targetStart + currentColumn > targetEnd Then
        targetPosition = targetEnd
    Else
        targetPosition = targetStart + currentColumn
    End If

    If extendSelection <> 0 Then
        textbox_ExtendSelection textData, targetPosition
    Else
        textbox_CollapseSelection textData, targetPosition
    End If

End Sub


Private Function textbox_LineForPosition(ByVal textValue As String, ByVal position As Integer) As Integer

    Dim lineIndex As Integer

    position = textbox_ClampPosition(textValue, position)

    For i As Integer = 0 To position - 1
        If textValue[i] = TEXTBOX_LINE_FEED Then
            lineIndex += 1
        Elseif textValue[i] = TEXTBOX_CARRIAGE_RETURN Then
            lineIndex += 1

            If i + 1 < position AndAlso textValue[i + 1] = TEXTBOX_LINE_FEED Then
                i += 1
            End If
        End If
    Next i

    Return lineIndex

End Function


Private Sub textbox_EnsureCursorVisible(ByVal w As Widget Ptr, ByVal textData As TextBoxData Ptr)

    Dim cursorColumnWidth As Integer
    Dim cursorLine As Integer
    Dim cursorLineEnd As Integer
    Dim cursorLineStart As Integer
    Dim visibleWidth As Integer
    Dim visibleLines As Integer

    If w = 0 OrElse textData = 0 Then Exit Sub

    textData->cursor_pos = textbox_ClampPosition(textData->text, textData->cursor_pos)
    textData->sel_start = textbox_ClampPosition(textData->text, textData->sel_start)
    textData->sel_end = textbox_ClampPosition(textData->text, textData->sel_end)
    textData->selection_anchor = textbox_ClampPosition( _
        textData->text, textData->selection_anchor _
    )

    textbox_UpdateScrollMetrics w, textData
    visibleWidth = textbox_ContentWidth(w, textData)
    cursorLine = textbox_VisualLineForPosition( _
        textData->text, textData->cursor_pos, _
        textData->wordwrap, visibleWidth _
    )
    visibleLines = textbox_VisibleLineCount(w)

    If textData->v_scroll < 0 Then textData->v_scroll = 0
    If cursorLine < textData->v_scroll Then textData->v_scroll = cursorLine
    If cursorLine >= textData->v_scroll + visibleLines Then textData->v_scroll = cursorLine - visibleLines + 1
    textbox_UpdateScrollMetrics w, textData

    If textData->wordwrap <> 0 Then
        textData->scroll_offset = 0
        Exit Sub
    End If

    If textbox_VisualLineBounds( _
        textData->text, cursorLine, textData->wordwrap, visibleWidth, _
        cursorLineStart, cursorLineEnd _
    ) = 0 Then
        cursorLineStart = textbox_LineStart( _
            textData->text, textData->cursor_pos _
        )
    End If
    cursorColumnWidth = backend_GetTextWidth( _
        Mid( _
            textData->text, cursorLineStart + 1, _
            textData->cursor_pos - cursorLineStart _
        ) _
    )
    If visibleWidth < TEXTBOX_CURSOR_VISIBLE_WIDTH Then _
        visibleWidth = TEXTBOX_CURSOR_VISIBLE_WIDTH

    If textData->scroll_offset < 0 OrElse _
       cursorColumnWidth < textData->scroll_offset Then
        textData->scroll_offset = cursorColumnWidth
    Elseif cursorColumnWidth + TEXTBOX_CURSOR_VISIBLE_WIDTH > _
           textData->scroll_offset + visibleWidth Then
        textData->scroll_offset = cursorColumnWidth + _
            TEXTBOX_CURSOR_VISIBLE_WIDTH - visibleWidth
    End If

End Sub


Private Sub textbox_RenderLine( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal lineIndex As Integer, _
    ByVal lineStart As Integer, _
    ByVal lineText As String _
)

    Dim drawX As Integer
    Dim drawY As Integer
    Dim postText As String
    Dim prefixText As String
    Dim selectedEnd As Integer
    Dim selectedStart As Integer
    Dim selectedText As String
    Dim selectedWidth As Integer
    Dim selectedX As Integer

    If w = 0 OrElse textData = 0 Then Exit Sub
    If lineIndex < textData->v_scroll Then Exit Sub

    drawY = w->ay + TEXTBOX_TEXT_LEFT_PADDING + (lineIndex - textData->v_scroll) * TEXTBOX_LINE_HEIGHT
    If drawY > w->ay + w->h - TEXTBOX_TEXT_BOTTOM_PADDING Then Exit Sub

    drawX = w->ax + TEXTBOX_TEXT_LEFT_PADDING
    If textData->wordwrap = 0 Then drawX -= textData->scroll_offset

    selectedStart = textData->sel_start
    selectedEnd = textData->sel_end
    If selectedEnd < selectedStart Then Swap selectedStart, selectedEnd
    If selectedStart < lineStart Then selectedStart = lineStart
    If selectedEnd > lineStart + Len(lineText) Then _
        selectedEnd = lineStart + Len(lineText)

    If selectedEnd <= selectedStart Then
        backend_Print drawX, drawY, current_theme.text_main, lineText
        Exit Sub
    End If

    prefixText = Left(lineText, selectedStart - lineStart)
    selectedText = Mid( _
        lineText, selectedStart - lineStart + 1, _
        selectedEnd - selectedStart _
    )
    postText = Mid(lineText, selectedEnd - lineStart + 1)
    selectedX = drawX + backend_GetTextWidth(prefixText)
    selectedWidth = backend_GetTextWidth(selectedText)

    backend_Print drawX, drawY, current_theme.text_main, prefixText

    If selectedWidth > 0 Then
        backend_Rect selectedX, drawY, selectedWidth, _
            TEXTBOX_LINE_HEIGHT, current_theme.bg_select, 1
    End If

    backend_Print selectedX, drawY, current_theme.text_select, selectedText
    backend_Print selectedX + selectedWidth, drawY, _
        current_theme.text_main, postText

End Sub


Private Sub textbox_HandleDeletionInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr _
)

    Dim position As Integer

    If textData = 0 Then Exit Sub

    If textbox_KeyJustPressed(textData, KEY_BACKSPACE, TEXTBOX_KEY_LATCH_BACKSPACE) <> 0 Then
        If textData->sel_start <> textData->sel_end Then
            textbox_BeginEdit w, TEXTBOX_HISTORY_GROUP_BACKSPACE
            textbox_DeleteSelection textData
        Else
            position = textbox_ClampPosition(textData->text, textData->cursor_pos)

            If position > 0 Then
                textbox_BeginEdit w, TEXTBOX_HISTORY_GROUP_BACKSPACE
                textData->text = Left(textData->text, position - 1) & Mid(textData->text, position + 1)
                textbox_CollapseSelection textData, position - 1
            End If
        End If
    Elseif textbox_KeyJustPressed(textData, KEY_DELETE, TEXTBOX_KEY_LATCH_DELETE) <> 0 Then
        If textData->sel_start <> textData->sel_end Then
            textbox_BeginEdit w, TEXTBOX_HISTORY_GROUP_DELETE
            textbox_DeleteSelection textData
        Else
            position = textbox_ClampPosition(textData->text, textData->cursor_pos)

            If position < Len(textData->text) Then
                textbox_BeginEdit w, TEXTBOX_HISTORY_GROUP_DELETE
                textData->text = Left(textData->text, position) & Mid(textData->text, position + 2)
                textbox_CollapseSelection textData, position
            End If
        End If
    End If

End Sub


Private Sub textbox_HandleNavigationInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr _
)

    Dim extendSelection As Integer

    If textData = 0 Then Exit Sub
    extendSelection = textbox_ShiftPressed()

    If textbox_KeyJustPressed(textData, KEY_RETURN, TEXTBOX_KEY_LATCH_RETURN) <> 0 Then
        If textData->multiline <> 0 Then
            textbox_BeginEdit w, TEXTBOX_HISTORY_GROUP_RETURN
            textbox_InsertText textData, Chr(TEXTBOX_LINE_FEED)
        Else
            textData->active = 0
        End If
    Elseif textbox_KeyJustPressed(textData, KEY_LEFT, TEXTBOX_KEY_LATCH_LEFT) <> 0 Then
        textbox_EndEditGroup w
        If extendSelection <> 0 Then
            textbox_ExtendSelection textData, textData->cursor_pos - 1
        Elseif textData->sel_start <> textData->sel_end Then
            textbox_CollapseSelection textData, textData->sel_start
        Else
            textbox_CollapseSelection textData, textData->cursor_pos - 1
        End If
    Elseif textbox_KeyJustPressed(textData, KEY_RIGHT, TEXTBOX_KEY_LATCH_RIGHT) <> 0 Then
        textbox_EndEditGroup w
        If extendSelection <> 0 Then
            textbox_ExtendSelection textData, textData->cursor_pos + 1
        Elseif textData->sel_start <> textData->sel_end Then
            textbox_CollapseSelection textData, textData->sel_end
        Else
            textbox_CollapseSelection textData, textData->cursor_pos + 1
        End If
    Elseif textbox_KeyJustPressed(textData, KEY_HOME, TEXTBOX_KEY_LATCH_HOME) <> 0 Then
        textbox_EndEditGroup w
        If extendSelection <> 0 Then
            textbox_ExtendSelection textData, _
                textbox_LineStart(textData->text, textData->cursor_pos)
        Else
            textbox_CollapseSelection textData, _
                textbox_LineStart(textData->text, textData->cursor_pos)
        End If
    Elseif textbox_KeyJustPressed(textData, KEY_END, TEXTBOX_KEY_LATCH_END) <> 0 Then
        textbox_EndEditGroup w
        If extendSelection <> 0 Then
            textbox_ExtendSelection textData, _
                textbox_LineEnd(textData->text, textData->cursor_pos)
        Else
            textbox_CollapseSelection textData, _
                textbox_LineEnd(textData->text, textData->cursor_pos)
        End If
    Elseif textData->multiline <> 0 AndAlso textbox_KeyJustPressed(textData, KEY_UP, TEXTBOX_KEY_LATCH_UP) <> 0 Then
        textbox_EndEditGroup w
        textbox_MoveCursorVertical w, textData, -1, extendSelection
    Elseif textData->multiline <> 0 AndAlso textbox_KeyJustPressed(textData, KEY_DOWN, TEXTBOX_KEY_LATCH_DOWN) <> 0 Then
        textbox_EndEditGroup w
        textbox_MoveCursorVertical w, textData, 1, extendSelection
    End If

End Sub


' -------------------------------------------------------------------------
' Context menu callbacks
' -------------------------------------------------------------------------

Private Sub ctx_copy(ByVal idx As Integer)

    Dim selectedText As String
    Dim textData As TextBoxData Ptr

    If active_textbox = 0 OrElse active_textbox->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, active_textbox->data)
    selectedText = textbox_SelectedText(textData)
    If selectedText <> "" Then clipboard_SetText selectedText

End Sub


Private Sub ctx_cut(ByVal idx As Integer)

    Dim selectedText As String
    Dim textData As TextBoxData Ptr

    If active_textbox = 0 OrElse active_textbox->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, active_textbox->data)
    selectedText = textbox_SelectedText(textData)
    If selectedText = "" Then Exit Sub

    clipboard_SetText selectedText
    textbox_BeginEdit active_textbox, TEXTBOX_HISTORY_GROUP_NONE
    textbox_DeleteSelection textData

End Sub


Private Sub ctx_paste(ByVal idx As Integer)

    If active_textbox <> 0 Then
        Dim pastedText As String

        pastedText = clipboard_GetText()

        If pastedText <> "" Then
            textbox_BeginEdit active_textbox, TEXTBOX_HISTORY_GROUP_NONE
            textbox_InsertText _
                Cast(TextBoxData Ptr, active_textbox->data), pastedText
        End If
    End If

End Sub


' -------------------------------------------------------------------------
' Mouse and control-key routing
' -------------------------------------------------------------------------

Private Sub textbox_HandleMouseInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr, _
    ByVal mouseX As Integer, _
    ByVal mouseY As Integer, _
    ByVal mouseButtons As Integer _
)

    Dim insideWidget As Integer

    If w = 0 OrElse textData = 0 Then Exit Sub

    insideWidget = IIf( _
        mouseX >= w->ax AndAlso mouseX < w->ax + w->w AndAlso _
        mouseY >= w->ay AndAlso mouseY < w->ay + w->h, _
        1, 0 _
    )

    If (mouseButtons And 1) <> 0 Then
        If textData->mouse_latch = 0 Then
            textData->mouse_latch = 1
            textbox_EndEditGroup w

            If insideWidget <> 0 Then
                textData->active = 1
                active_textbox = w

                If textbox_ShiftPressed() <> 0 Then
                    textbox_ExtendSelection textData, _
                        textbox_PositionFromPoint( _
                            w, textData, mouseX, mouseY _
                        )
                Else
                    textbox_CollapseSelection textData, _
                        textbox_PositionFromPoint( _
                            w, textData, mouseX, mouseY _
                        )
                End If

                textData->mouse_selecting = 1
            Else
                textData->active = 0
                textData->mouse_selecting = 0
                If active_textbox = w Then active_textbox = 0
            End If
        Elseif textData->mouse_selecting <> 0 Then
            textbox_ExtendSelection textData, _
                textbox_PositionFromPoint(w, textData, mouseX, mouseY)
        End If
    Else
        textData->mouse_latch = 0
        textData->mouse_selecting = 0
    End If

    If (mouseButtons And 2) = 0 OrElse insideWidget = 0 Then Exit Sub

    textData->active = 1
    active_textbox = w

    If textbox_context_menu = 0 Then
        textbox_context_menu = menu_Create("tb_ctx", mouseX, mouseY)
        menu_AddItem textbox_context_menu, "Copy", @ctx_copy
        menu_AddItem textbox_context_menu, "Cut", @ctx_cut
        menu_AddItem textbox_context_menu, "Paste", @ctx_paste
        gui_AddWidget textbox_context_menu
    End If

    textbox_context_menu->x = mouseX
    textbox_context_menu->y = mouseY
    textbox_context_menu->visible = 1
    gui_BringToFront textbox_context_menu

End Sub


Private Function textbox_HandleControlInput( _
    ByVal w As Widget Ptr, _
    ByVal textData As TextBoxData Ptr _
) As Integer

    If w = 0 OrElse textData = 0 OrElse _
       input_KeyPressed(FB.SC_CONTROL) = 0 Then
        Return 0
    End If

    If textbox_KeyJustPressed( _
        textData, FB.SC_Z, TEXTBOX_KEY_LATCH_UNDO _
    ) <> 0 Then
        textbox_EndEditGroup w
        textbox_Undo w
        textbox_EnsureCursorVisible w, textData
        Return 1
    End If

    If textbox_KeyJustPressed( _
        textData, FB.SC_Y, TEXTBOX_KEY_LATCH_REDO _
    ) <> 0 Then
        textbox_EndEditGroup w
        textbox_Redo w
        textbox_EnsureCursorVisible w, textData
        Return 1
    End If

    If textbox_KeyJustPressed( _
        textData, FB.SC_A, TEXTBOX_KEY_LATCH_SELECT_ALL _
    ) <> 0 Then
        textbox_EndEditGroup w
        textData->selection_anchor = 0
        textbox_ExtendSelection textData, Len(textData->text)
        textbox_EnsureCursorVisible w, textData
        Return 1
    End If

    If textbox_KeyJustPressed( _
        textData, FB.SC_C, TEXTBOX_KEY_LATCH_COPY _
    ) <> 0 Then
        textbox_EndEditGroup w
        ctx_copy 0
        textbox_EnsureCursorVisible w, textData
        Return 1
    End If

    If textbox_KeyJustPressed( _
        textData, FB.SC_X, TEXTBOX_KEY_LATCH_CUT _
    ) <> 0 Then
        textbox_EndEditGroup w
        ctx_cut 0
        textbox_EnsureCursorVisible w, textData
        Return 1
    End If

    If textbox_KeyJustPressed( _
        textData, FB.SC_V, TEXTBOX_KEY_LATCH_PASTE _
    ) <> 0 Then
        textbox_EndEditGroup w
        ctx_paste 0
        textbox_EnsureCursorVisible w, textData
        Return 1
    End If

End Function


' -------------------------------------------------------------------------
' Public widget API
' -------------------------------------------------------------------------

Function textbox_Create( _
    ByVal nm As String, ByVal txt As String, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal m As Integer, ByVal ww As Integer, _
    ByVal scrollbarMode As Integer _
) As Widget Ptr

    Dim wgt As Widget Ptr
    Dim textData As TextBoxData Ptr

    wgt = New Widget
    textData = New TextBoxData

    wgt->name = nm
    wgt->x = x
    wgt->y = y
    wgt->w = w
    wgt->h = h
    wgt->visible = 1
    wgt->enabled = 1
    wgt->accepts_focus = -1
    wgt->render = @textbox_Render
    wgt->update = @textbox_Update
    wgt->destroy = @textbox_Destroy

    textData->text = txt
    textData->active = 0
    textData->multiline = m
    textData->wordwrap = ww
    textData->cursor_pos = Len(txt)
    textData->sel_start = textData->cursor_pos
    textData->sel_end = textData->cursor_pos
    textData->selection_anchor = textData->cursor_pos
    textData->scroll_offset = 0
    textData->v_scroll = 0
    textData->key_latch = 0
    textData->mouse_latch = 0
    textData->mouse_selecting = 0
    textData->scrollbar_dragging = 0
    textData->scrollbar_mode = scrollbarMode
    textData->scrollbar_visible = 0
    textData->total_visual_lines = 1
    textData->viewport_dirty = -1
    textData->observed_text_length = Len(txt)
    textData->observed_cursor_pos = textData->cursor_pos
    textData->vertical_scrollbar = scrollbar_Create( _
        nm & "_vertical_scrollbar", 0, 0, _
        TEXTBOX_SCROLLBAR_WIDTH, h, 0, 1, -1 _
    )
    textData->undoCount = 0
    textData->redoCount = 0
    textData->historyStoredBytes = 0
    textData->historyGroup = TEXTBOX_HISTORY_GROUP_NONE
    textData->historyIdleFrames = 0
    wgt->data = textData

    Return wgt

End Function


Sub textbox_Render(ByVal w As Widget Ptr)

    Dim textData As TextBoxData Ptr
    Dim lineText As String
    Dim lineStart As Integer
    Dim lineIndex As Integer
    Dim lineEnd As Integer
    Dim scanPosition As Integer
    Dim textClipHeight As Integer
    Dim textClipWidth As Integer
    Dim contentWidth As Integer
    Dim cursorLine As Integer
    Dim cursorX As Integer
    Dim cursorY As Integer
    Dim cursorRecorded As Integer

    If w = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, w->data)
    If textData = 0 Then Exit Sub

    If w->has_focus = 0 Then
        textData->active = 0
        If active_textbox = w Then active_textbox = 0
    End If

    textbox_UpdateScrollMetrics w, textData

    backend_Rect w->ax, w->ay, w->w, w->h, current_theme.bg_dark, 0
    backend_Rect w->ax + 1, w->ay + 1, w->w - 2, w->h - 2, current_theme.bg_light, 1
    textClipWidth = w->w - 4
    If textData->scrollbar_visible <> 0 Then
        textClipWidth -= TEXTBOX_SCROLLBAR_WIDTH + TEXTBOX_SCROLLBAR_INSET
    End If
    If textClipWidth < 1 Then textClipWidth = 1
    textClipHeight = w->h - 4
    If textClipHeight < 1 Then textClipHeight = 1
    backend_SetClip w->ax + 2, w->ay + 2, _
        textClipWidth, textClipHeight

    textData->cursor_pos = textbox_ClampPosition(textData->text, textData->cursor_pos)
    contentWidth = textbox_ContentWidth(w, textData)

    While textbox_NextVisualLine( _
        textData->text, scanPosition, textData->wordwrap, contentWidth, _
        lineStart, lineEnd _
    )
        If cursorRecorded = 0 AndAlso _
           textData->cursor_pos >= lineStart AndAlso _
           textData->cursor_pos <= lineEnd Then
            cursorLine = lineIndex
            cursorX = w->ax + TEXTBOX_TEXT_LEFT_PADDING + _
                backend_GetTextWidth( _
                    Mid( _
                        textData->text, lineStart + 1, _
                        textData->cursor_pos - lineStart _
                    ) _
                )
            If textData->wordwrap = 0 Then _
                cursorX -= textData->scroll_offset
            cursorY = w->ay + TEXTBOX_TEXT_LEFT_PADDING + (lineIndex - textData->v_scroll) * TEXTBOX_LINE_HEIGHT
            cursorRecorded = 1
        End If

        lineText = Mid(textData->text, lineStart + 1, lineEnd - lineStart)
        textbox_RenderLine w, textData, lineIndex, lineStart, lineText
        lineIndex += 1
    Wend

    If cursorRecorded <> 0 AndAlso textData->active <> 0 AndAlso _
       cursorLine >= textData->v_scroll AndAlso _
       cursorY <= w->ay + w->h - TEXTBOX_TEXT_BOTTOM_PADDING AndAlso _
       Int(Timer * 2) Mod 2 = 0 Then
        backend_Print cursorX, cursorY, current_theme.text_main, "|"
    End If

    backend_ResetClip()

    If textData->scrollbar_visible <> 0 AndAlso _
       textData->vertical_scrollbar <> 0 Then
        textData->vertical_scrollbar->render(textData->vertical_scrollbar)
    End If

End Sub


Sub textbox_Update(ByVal w As Widget Ptr)

    Dim textData As TextBoxData Ptr
    Dim mouseX As Integer
    Dim mouseY As Integer
    Dim mouseButtons As Integer
    Dim previousCursor As Integer
    Dim previousText As String
    Dim typedText As String
    Dim viewportChanged As Integer

    If w = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, w->data)
    If textData = 0 Then Exit Sub

    mouseX = input_MouseX()
    mouseY = input_MouseY()
    mouseButtons = input_MouseButtons()
    previousCursor = textData->cursor_pos
    previousText = textData->text
    viewportChanged = IIf( _
        textData->viewport_dirty <> 0 OrElse _
        textData->observed_text_length <> Len(textData->text) OrElse _
        textData->observed_cursor_pos <> textData->cursor_pos, _
        1, 0 _
    )
    textbox_UpdateScrollMetrics w, textData

    If textbox_HandleScrollInput( _
        w, textData, mouseX, mouseY, mouseButtons _
    ) = 0 Then
        textbox_HandleMouseInput w, textData, mouseX, mouseY, mouseButtons
    End If

    If textData->active = 0 Then
        If active_textbox = w Then active_textbox = 0
        textData->key_latch = 0
        textbox_EndEditGroup w
        If viewportChanged <> 0 Then textbox_EnsureCursorVisible w, textData
        textData->viewport_dirty = 0
        textData->observed_text_length = Len(textData->text)
        textData->observed_cursor_pos = textData->cursor_pos
        Exit Sub
    End If

    active_textbox = w
    textbox_RefreshKeyLatch textData

    If textbox_HandleControlInput(w, textData) <> 0 Then
        textData->viewport_dirty = 0
        textData->observed_text_length = Len(textData->text)
        textData->observed_cursor_pos = textData->cursor_pos
        Exit Sub
    End If

    typedText = input_PollTextInput()
    If typedText <> "" Then
        textbox_BeginEdit w, TEXTBOX_HISTORY_GROUP_TYPING
        textbox_InsertText textData, typedText
    End If

    textbox_HandleDeletionInput w, textData
    textbox_HandleNavigationInput w, textData

    If textData->historyGroup <> TEXTBOX_HISTORY_GROUP_NONE Then
        textData->historyIdleFrames += 1

        If textData->historyIdleFrames >= _
           TEXTBOX_HISTORY_IDLE_FRAME_LIMIT Then
            textbox_EndEditGroup w
        End If
    End If

    If viewportChanged <> 0 OrElse _
       previousCursor <> textData->cursor_pos OrElse _
       previousText <> textData->text Then
        textbox_EnsureCursorVisible w, textData
        textData->viewport_dirty = 0
    Else
        textbox_UpdateScrollMetrics w, textData
    End If
    textData->observed_text_length = Len(textData->text)
    textData->observed_cursor_pos = textData->cursor_pos

End Sub


Sub textbox_SetVerticalScrollbar( _
    ByVal w As Widget Ptr, ByVal scrollbarMode As Integer _
)
    Dim As TextBoxData Ptr textData

    If w = 0 OrElse w->data = 0 Then Exit Sub
    textData = Cast(TextBoxData Ptr, w->data)

    If scrollbarMode < TEXTBOX_SCROLLBAR_NONE OrElse _
       scrollbarMode > TEXTBOX_SCROLLBAR_ALWAYS Then
        scrollbarMode = TEXTBOX_SCROLLBAR_AUTO
    End If

    textData->scrollbar_mode = scrollbarMode
    If scrollbarMode = TEXTBOX_SCROLLBAR_NONE Then textData->v_scroll = 0
    textbox_UpdateScrollMetrics w, textData
End Sub


Function textbox_GetVerticalScrollbarMode( _
    ByVal w As Widget Ptr _
) As Integer
    Dim As TextBoxData Ptr textData

    If w = 0 OrElse w->data = 0 Then Return TEXTBOX_SCROLLBAR_NONE
    textData = Cast(TextBoxData Ptr, w->data)
    Return textData->scrollbar_mode
End Function


Sub textbox_Destroy(ByVal w As Widget Ptr)

    Dim As TextBoxData Ptr textData

    If w = 0 Then Exit Sub
    If active_textbox = w Then active_textbox = 0
    textData = Cast(TextBoxData Ptr, w->data)

    If textData <> 0 Then
        If textData->vertical_scrollbar <> 0 Then
            If textData->vertical_scrollbar->destroy <> 0 Then _
                textData->vertical_scrollbar->destroy( _
                    textData->vertical_scrollbar _
                )
            Delete textData->vertical_scrollbar
            textData->vertical_scrollbar = 0
        End If

        Delete textData
        w->data = 0
    End If

End Sub

' end of textbox.bas

/'
    Project: omaGUI
    ---------------
    File: input_gfxlib.bas

    Purpose:
        Implement the input abstraction with FreeBASIC gfxlib calls.

    Responsibilities:
        - poll mouse position, buttons, wheel movement, keys, and text input
        - expose per-widget pointer and keyboard dispatch masks
        - provide deterministic input values for GUI tests

    This file intentionally does NOT contain:
        - widget-specific input behavior
        - graphics rendering
'/

#lang "fb"

#include once "src/widgets/widgets.bi"

/'
    The backend is compiled into omaGUI as a collection of include modules,
    so its private polling state must be shared with the accessor routines in
    this file.  It is not part of the public input API.
'/
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mX, mY, mButtons, mWheelDelta
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer previousWheelPosition, wheelPositionInitialized
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockX, mockY, mockButtons, mockWheelDelta
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer useMockMouse, useMockKeys, useMockText
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer pointerDispatchEnabled = -1, keyboardDispatchEnabled = -1
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As String textBuffer, mockText

' FreeBASIC gfxlib scan codes are represented by one unsigned byte.
Const INPUT_KEY_LAST = 255
' FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared As Integer mockKeys(0 To INPUT_KEY_LAST)

' Printable single-byte input is intentionally limited to the ASCII range.
Const INPUT_TEXT_BYTE_INDEX = 0
Const INPUT_TEXT_BYTE_COUNT = 1
Const INPUT_TEXT_ASCII_FIRST = 32
Const INPUT_TEXT_ASCII_LAST = 126

Sub input_Update()
    Dim As Long MouseStatus
    Dim As Integer currentWheelPosition
    Dim As String KeyText

    pointerDispatchEnabled = -1
    keyboardDispatchEnabled = -1

    If useMockMouse Then
        mX = mockX
        mY = mockY
        mButtons = mockButtons
        mWheelDelta = mockWheelDelta
        mockWheelDelta = 0
    Else
        /'
            gfxlib returns nonzero when no mouse is available and writes -1
            into every output.  The coordinate sentinel is useful to callers,
            but -1 is an invalid button bitmask that would read as every button
            pressed unless it is cleared here.
        '/
        MouseStatus = GetMouse(mX, mY, currentWheelPosition, mButtons)
        If MouseStatus <> 0 Then
            mX = -1
            mY = -1
            mButtons = 0
            mWheelDelta = 0
            wheelPositionInitialized = 0
        Else
            If wheelPositionInitialized <> 0 Then
                mWheelDelta = currentWheelPosition - previousWheelPosition
            Else
                mWheelDelta = 0
                wheelPositionInitialized = -1
            End If

            previousWheelPosition = currentWheelPosition
        End If
    End If

    If useMockText Then
        textBuffer = mockText
        mockText = ""
        Exit Sub
    End If

    textBuffer = ""
    KeyText = Inkey

    While KeyText <> ""
        If Len(KeyText) = INPUT_TEXT_BYTE_COUNT Then
            If KeyText[INPUT_TEXT_BYTE_INDEX] >= INPUT_TEXT_ASCII_FIRST And _
               KeyText[INPUT_TEXT_BYTE_INDEX] <= INPUT_TEXT_ASCII_LAST Then
                textBuffer &= KeyText
            End If
        End If

        KeyText = Inkey
    Wend
End Sub

Function input_MouseX() As Integer
    If pointerDispatchEnabled = 0 Then Return -1
    Return mX
End Function

Function input_MouseY() As Integer
    If pointerDispatchEnabled = 0 Then Return -1
    Return mY
End Function

Function input_MouseButtons() As Integer
    If pointerDispatchEnabled = 0 Then Return 0
    Return mButtons
End Function

Function input_MouseWheel() As Integer
    If pointerDispatchEnabled = 0 Then Return 0
    Return mWheelDelta
End Function

Function input_KeyPressed(ByVal k As Integer) As Integer
    If k < 0 OrElse k > INPUT_KEY_LAST Then Return 0
    If keyboardDispatchEnabled = 0 Then Return 0

    If useMockKeys Then Return mockKeys(k)
    Return MultiKey(k)
End Function

Function input_PollTextInput() As String
    If keyboardDispatchEnabled = 0 Then Return ""
    Return textBuffer
End Function

Sub input_SetDispatchMask( _
    ByVal pointerEnabled As Integer, _
    ByVal keyboardEnabled As Integer _
)
    pointerDispatchEnabled = IIf(pointerEnabled <> 0, -1, 0)
    keyboardDispatchEnabled = IIf(keyboardEnabled <> 0, -1, 0)
End Sub

Sub input_MockMouse( _
    ByVal x As Integer, ByVal y As Integer, ByVal b As Integer, _
    ByVal wheelDelta As Integer _
)
    mockX = x
    mockY = y
    mockButtons = b
    mockWheelDelta = wheelDelta
    useMockMouse = 1
End Sub

Sub input_MockKey(ByVal k As Integer, ByVal state As Integer)
    If k < 0 Or k > INPUT_KEY_LAST Then Exit Sub

    mockKeys(k) = state
    useMockKeys = 1
End Sub

Sub input_MockText(ByVal txt As String)
    mockText = txt
    useMockText = 1
End Sub

Sub input_ResetForTest()
    mX = 0
    mY = 0
    mWheelDelta = 0
    mButtons = 0
    mockX = 0
    mockY = 0
    mockButtons = 0
    mockWheelDelta = 0
    previousWheelPosition = 0
    wheelPositionInitialized = 0
    useMockMouse = 1
    useMockKeys = 1
    useMockText = 1
    textBuffer = ""
    mockText = ""
    pointerDispatchEnabled = -1
    keyboardDispatchEnabled = -1

    For keyIndex As Integer = 0 To INPUT_KEY_LAST
        mockKeys(keyIndex) = 0
    Next keyIndex
End Sub

' end of input_gfxlib.bas

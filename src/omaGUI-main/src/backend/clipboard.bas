/'
    Project: omaGUI
    ---------------

    File: clipboard.bas

    Purpose:

        Exchange bounded plain text with the host clipboard.

    Responsibilities:

        - use the Win32 CF_TEXT clipboard on Windows
        - use xclip when it is available on Unix-like desktops
        - retain an in-process fallback when a platform clipboard is absent
        - permit applications to force the in-process portable fallback
        - reject unbounded clipboard payload growth

    This file intentionally does NOT contain:

        - widget focus or selection rules
        - rich-text conversion
        - image clipboard formats
'/

#lang "fb"

#include once "src/backend/clipboard.bi"

#if defined(OMAGUI_PORTABLE_ONLY)
    /' No platform declarations are imported in portable-only builds. '/
#elseif defined(__FB_WIN32__)
    #include once "windows.bi"
#elseif defined(__FB_LINUX__) or defined(__FB_FREEBSD__) or defined(__FB_OPENBSD__)
    #include once "crt.bi"
#endif

' -------------------------------------------------------------------------
' Process-local fallback
' -------------------------------------------------------------------------

' This is the boundary-owned fallback used only when the host API is absent. FB-LINTER: DISABLE-NEXT-LINE FBL301
Dim Shared clipboard_FallbackText As String


Private Function clipboard_BoundedText(ByVal textValue As String) As String

    If Len(textValue) > CLIPBOARD_MAX_TEXT_BYTES Then
        Return Left(textValue, CLIPBOARD_MAX_TEXT_BYTES)
    End If

    Return textValue

End Function

' -------------------------------------------------------------------------
' Windows clipboard helpers
' -------------------------------------------------------------------------

#if defined(__FB_WIN32__) and not defined(OMAGUI_PORTABLE_ONLY)

Const CLIPBOARD_WINDOWS_OPEN_ATTEMPTS As Integer = 5
Const CLIPBOARD_WINDOWS_RETRY_MILLISECONDS As Integer = 1


Private Function clipboard_WindowsOpen() As Integer

    For attemptIndex As Integer = 1 To CLIPBOARD_WINDOWS_OPEN_ATTEMPTS
        If OpenClipboard(0) <> 0 Then Return 1
        Sleep CLIPBOARD_WINDOWS_RETRY_MILLISECONDS, 1
    Next attemptIndex

    Return 0

End Function


Private Function clipboard_WindowsGetText() As String

    Dim byteCount As ULongInt
    Dim clipboardHandle As HANDLE
    Dim clipboardMemory As Any Ptr
    Dim resultText As String

    If IsClipboardFormatAvailable(CF_TEXT) = 0 Then Return ""
    If clipboard_WindowsOpen() = 0 Then Return ""

    clipboardHandle = GetClipboardData(CF_TEXT)

    If clipboardHandle <> 0 Then
        clipboardMemory = GlobalLock(clipboardHandle)

        If clipboardMemory <> 0 Then
            byteCount = GlobalSize(clipboardHandle)

            If byteCount > 0 Then
                resultText = *Cast(ZString Ptr, clipboardMemory)
                resultText = clipboard_BoundedText(resultText)
            End If

            ' GlobalUnlock is imported only inside the Win32 branch. FB-LINTER: DISABLE-NEXT-LINE FBL310
            GlobalUnlock clipboardHandle
        End If
    End If

    CloseClipboard()
    Return resultText

End Function


Private Function clipboard_WindowsSetText(ByVal textValue As String) As Integer

    Dim allocationFlags As UINT
    Dim clipboardHandle As HANDLE
    Dim clipboardMemory As Any Ptr
    Dim clipboardResult As HANDLE

    If clipboard_WindowsOpen() = 0 Then Return 0

    If EmptyClipboard() = 0 Then
        CloseClipboard()
        Return 0
    End If

    ' These flags select an owned, movable, zero-filled Win32 block. FB-LINTER: DISABLE-NEXT-LINE FBL310
    allocationFlags = GMEM_MOVEABLE Or GMEM_ZEROINIT
    clipboardHandle = GlobalAlloc(allocationFlags, Len(textValue) + 1)

    If clipboardHandle = 0 Then
        CloseClipboard()
        Return 0
    End If

    clipboardMemory = GlobalLock(clipboardHandle)

    If clipboardMemory = 0 Then
        GlobalFree clipboardHandle ' Win32 conditional import. FB-LINTER: DISABLE-LINE FBL310
        CloseClipboard()
        Return 0
    End If

    *Cast(ZString Ptr, clipboardMemory) = textValue
    GlobalUnlock clipboardHandle ' Win32 conditional import. FB-LINTER: DISABLE-LINE FBL310
    clipboardResult = SetClipboardData(CF_TEXT, clipboardHandle)

    If clipboardResult = 0 Then GlobalFree clipboardHandle ' Win32 conditional import. FB-LINTER: DISABLE-LINE FBL310
    CloseClipboard()

    Return IIf(clipboardResult <> 0, 1, 0)

End Function

#endif

' -------------------------------------------------------------------------
' Public clipboard API
' -------------------------------------------------------------------------

Function clipboard_GetText() As String

    Dim resultText As String

#if defined(OMAGUI_PORTABLE_ONLY)
    Return clipboard_BoundedText(clipboard_FallbackText)
#elseif defined(__FB_WIN32__)
    resultText = clipboard_WindowsGetText()
    Return clipboard_BoundedText(resultText)
#elseif defined(__FB_LINUX__) or defined(__FB_FREEBSD__) or defined(__FB_OPENBSD__)
    Dim clipboardFile As FILE Ptr
    Dim readBuffer As ZString * 1024

    clipboardFile = popen("xclip -o -selection clipboard 2>/dev/null", "r")

    If clipboardFile <> 0 Then
        While fgets(readBuffer, SizeOf(readBuffer), clipboardFile) <> 0 AndAlso _
              Len(resultText) < CLIPBOARD_MAX_TEXT_BYTES
            resultText &= readBuffer
        Wend

        pclose clipboardFile ' Unix CRT conditional import. FB-LINTER: DISABLE-LINE FBL310
        resultText = clipboard_BoundedText(resultText)
    End If

    If resultText = "" Then resultText = clipboard_FallbackText
    Return clipboard_BoundedText(resultText)
#else
    Return clipboard_BoundedText(clipboard_FallbackText)
#endif

End Function


Sub clipboard_SetText(ByVal txt As String)

    clipboard_FallbackText = clipboard_BoundedText(txt)

#if defined(OMAGUI_PORTABLE_ONLY)
    /' The process-local value assigned above is the complete implementation. '/
#elseif defined(__FB_WIN32__)
    clipboard_WindowsSetText clipboard_FallbackText
#elseif defined(__FB_LINUX__) or defined(__FB_FREEBSD__) or defined(__FB_OPENBSD__)
    Dim clipboardFile As FILE Ptr

    clipboardFile = popen("xclip -selection clipboard 2>/dev/null", "w")

    If clipboardFile <> 0 Then
        fputs clipboard_FallbackText, clipboardFile ' Unix CRT conditional import. FB-LINTER: DISABLE-LINE FBL310
        pclose clipboardFile ' Unix CRT conditional import. FB-LINTER: DISABLE-LINE FBL310
    End If
#endif

End Sub

' end of clipboard.bas

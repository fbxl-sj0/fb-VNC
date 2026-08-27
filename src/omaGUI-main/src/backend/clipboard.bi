/'
    Project: omaGUI
    ---------------

    File: clipboard.bi

    Purpose:

        Declare the bounded plain-text clipboard used by editable widgets.

    Responsibilities:

        - expose clipboard text reads and writes
        - define the maximum accepted clipboard payload

    This file intentionally does NOT contain:

        - platform API calls
        - textbox selection rules
        - rich-text or image clipboard formats
'/

#ifndef __CLIPBOARD_BI__
#define __CLIPBOARD_BI__

Const CLIPBOARD_MAX_TEXT_BYTES As Integer = 2097152

Declare Function clipboard_GetText() As String
Declare Sub clipboard_SetText(ByVal txt As String)

#endif
' end of clipboard.bi

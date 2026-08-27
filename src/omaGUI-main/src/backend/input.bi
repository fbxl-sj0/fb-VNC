/'
    Project: omaGUI
    ---------------
    File: input.bi

    Purpose:
        Declare the gfxlib input and deterministic test-input interface.

    Responsibilities:
        - expose mouse position, buttons, wheel movement, keys, and text
        - allow the GUI manager to route one pointer event to one widget
        - provide deterministic mouse, wheel, keyboard, and text test input

    This file intentionally does NOT contain:
        - platform polling implementation
        - widget hit testing
        - window focus policy
'/

#ifndef __INPUT_BI__
#define __INPUT_BI__

#include "fbgfx.bi"

' -------------------------------------------------------------------------
' Input API
' -------------------------------------------------------------------------

Declare Sub input_Update()
Declare Function input_MouseX() As Integer
Declare Function input_MouseY() As Integer
Declare Function input_MouseButtons() As Integer
Declare Function input_MouseWheel() As Integer
Declare Function input_KeyPressed(ByVal k As Integer) As Integer
Declare Function input_PollTextInput() As String
Declare Sub input_SetDispatchMask( _
    ByVal pointerEnabled As Integer, _
    ByVal keyboardEnabled As Integer _
)

Declare Sub input_MockMouse( _
    ByVal x As Integer, ByVal y As Integer, ByVal b As Integer, _
    ByVal wheelDelta As Integer = 0 _
)
Declare Sub input_MockKey(ByVal k As Integer, ByVal state As Integer)
Declare Sub input_MockText(ByVal txt As String)
Declare Sub input_ResetForTest()

#define KEY_BACKSPACE FB.SC_BACKSPACE
#define KEY_ESCAPE    FB.SC_ESCAPE
#define KEY_RETURN    FB.SC_ENTER
' gfxlib exposes one Enter scan code on the portable FreeBASIC input surface.
#define KEY_KP_ENTER  FB.SC_ENTER
#define KEY_DELETE    FB.SC_DELETE
#define KEY_HOME      FB.SC_HOME
#define KEY_END       FB.SC_END
#define KEY_UP        FB.SC_UP
#define KEY_DOWN      FB.SC_DOWN
#define KEY_LEFT      FB.SC_LEFT
#define KEY_RIGHT     FB.SC_RIGHT

#endif

' end of input.bi

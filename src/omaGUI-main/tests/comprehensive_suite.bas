/'
    Project: omaGUI
    ---------------

    File: comprehensive_suite.bas

    Purpose:

        Run the broad interaction and widget logic regression suite.

    Responsibilities:

        - verify ordinary widget pointer and keyboard behavior
        - verify textbox and list state transitions
        - report results through the common test harness

    This file intentionally does NOT contain:

        - visual screenshot comparisons
        - native window-driver tests
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION

#include once "omaGUI.bi"
#include once "tests/test_harness.bi"

Print "omaGUI Comprehensive Logic Test Suite"
backend_Init(800, 600)
gui_Init()

' --- 1. Test Button Interaction (Hold/Exit/Release) ---
Print "Testing Button Interaction Logic..."
Dim As Widget Ptr btn = button_Create("btn", "Test", 10, 10, 50, 20)
gui_AddWidget(btn)
Dim As ButtonData Ptr bd = btn->data

' Hover
input_MockMouse(15, 15, 0) : gui_UpdateAll()
AssertTrue bd->state = 1, "Button hover state"

' Press
input_MockMouse(15, 15, 1) : gui_UpdateAll()
AssertTrue bd->state = 2, "Button press state"

' Exit while holding
input_MockMouse(100, 100, 1) : gui_UpdateAll()
AssertTrue bd->state = 0, "Button exit while holding"

' Re-enter while holding
input_MockMouse(15, 15, 1) : gui_UpdateAll()
AssertTrue bd->state = 2, "Button re-enter while holding"

' Release
input_MockMouse(15, 15, 0) : gui_UpdateAll()
AssertTrue gui_ButtonPressed("btn") <> 0, "Button click release"

' --- 2. Test RadioBox Exclusivity ---
Print "Testing RadioBox Exclusivity..."
Dim As Widget Ptr r1 = radiobox_Create("r1", "Opt1", 10, 50, 1, 1)
Dim As Widget Ptr r2 = radiobox_Create("r2", "Opt2", 10, 70, 1, 0)
gui_AddWidget(r1) : gui_AddWidget(r2)

' Click R2
input_MockMouse(15, 75, 1) : gui_UpdateAll()
input_MockMouse(15, 75, 0) : gui_UpdateAll()

Dim As RadioBoxData Ptr rd1 = r1->data
Dim As RadioBoxData Ptr rd2 = r2->data
AssertTrue rd1->selected = 0 AndAlso rd2->selected = 1, _
    "RadioBox exclusivity"

' --- 3. Test ScrollBar Draggable ---
Print "Testing ScrollBar Dragging..."
Dim As Widget Ptr sb = scrollbar_Create("sb", 100, 100, 20, 100, 100)
gui_AddWidget(sb)
Dim As ScrollBarData Ptr sbd = sb->data

input_MockMouse(110, 150, 1) : gui_UpdateAll() ' Click middle
AssertTrue sbd->value >= 40 AndAlso sbd->value <= 60, _
    "Scrollbar drag value"
input_MockMouse(110, 150, 0) : gui_UpdateAll()

' --- 4. Test Multi-line TextBox Entry ---
Print "Testing Multi-line Text Entry..."
Dim As Widget Ptr tb = textbox_Create("tb", "", 200, 200, 100, 50, 1, 0)
gui_AddWidget(tb)
Dim As TextBoxData Ptr tbd = tb->data

input_MockMouse(210, 210, 1) : gui_UpdateAll() ' Focus
input_MockMouse(210, 210, 0) : gui_UpdateAll()
input_MockText("Line1") : gui_UpdateAll()
input_MockKey(KEY_RETURN, 1) : gui_UpdateAll() : input_MockKey(KEY_RETURN, 0) ' Newline
input_MockText("Line2") : gui_UpdateAll()

AssertTrue InStr(tbd->text, "Line1") <> 0 AndAlso _
    InStr(tbd->text, "Line2") <> 0, "Multi-line text entry"

Print "Comprehensive Tests Finished."
backend_Exit()
test_Summary()

/' end of comprehensive_suite.bas '/

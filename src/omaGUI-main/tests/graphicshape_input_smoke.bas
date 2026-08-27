/'
    Project: omaGUI Test Suite
    --------------------------

    File: graphicshape_input_smoke.bas

    Purpose:

        Verify opt-in input behavior for imported control-shaped graphics.

    Responsibilities:

        - prove imported controls receive routed input inside a parent window
        - prove buttons, checks, choices, text, dates, and values retain state
        - prove pointer, keyboard text, and wheel changes notify applications

    This file intentionally does NOT contain:

        - imported file parsing
        - screenshot comparison
        - application-specific HMI commands
'/

#lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "../omaGUI.bi"

Dim Shared As Integer graphicInputChangeCount

Private Sub graphicInput_OnChange(ByVal w As Widget Ptr)
    If w <> 0 Then graphicInputChangeCount += 1
End Sub


Private Sub graphicInput_Fail( _
    ByVal messageText As String, ByVal exitCode As Integer _
)
    gui_ResetForTest
    backend_Exit
    Print "graphic shape input smoke failed: " & messageText
    End exitCode
End Sub


Private Sub graphicInput_Click( _
    ByVal w As Widget Ptr, _
    ByVal local_x As Integer = -1, _
    ByVal local_y As Integer = -1 _
)
    Dim As Integer click_x
    Dim As Integer click_y

    If w = 0 Then Exit Sub
    If local_x < 0 Then local_x = w->w \ 2
    If local_y < 0 Then local_y = w->h \ 2
    click_x = w->ax + local_x
    click_y = w->ay + local_y

    input_MockMouse click_x, click_y, 1
    gui_UpdateAll
    input_MockMouse click_x, click_y, 0
    gui_UpdateAll
End Sub


Private Function graphicInput_Create( _
    ByVal parent As Widget Ptr, _
    ByVal nameText As String, ByVal shapeKind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer = 80, ByVal h As Integer = 48 _
) As Widget Ptr
    Dim As Widget Ptr shapeWidget

    shapeWidget = graphicshape_Create( _
        nameText, shapeKind, x, y, w, h, _
        RGB(30, 50, 80), RGB(230, 235, 245), -1, nameText _
    )
    If shapeWidget = 0 Then Return 0

    gui_AddWidget shapeWidget
    gui_SetParent shapeWidget, parent
    graphicshape_SetInteractive shapeWidget, -1, @graphicInput_OnChange
    Return shapeWidget
End Function


Dim As Widget Ptr alarmShape
Dim As Widget Ptr buttonShape
Dim As Widget Ptr calendarShape
Dim As Widget Ptr checkboxShape
Dim As Widget Ptr comboShape
Dim As GraphicShapeData Ptr comboData
Dim As Widget Ptr controlShape
Dim As Widget Ptr dateShape
Dim As GraphicShapeData Ptr dateData
Dim As Widget Ptr editShape
Dim As Widget Ptr listShape
Dim As Widget Ptr parentWindow
Dim As Widget Ptr radioShape
Dim As Widget Ptr trendShape

backend_Init 640, 360, -1
gui_Init
input_ResetForTest

parentWindow = subwindow_Create( _
    "input_parent", "Imported control input", 20, 20, 600, 310 _
)
gui_AddWidget parentWindow

buttonShape = graphicInput_Create( _
    parentWindow, "button_shape", GUI_SHAPE_BUTTON, 10, 30 _
)
checkboxShape = graphicInput_Create( _
    parentWindow, "checkbox_shape", GUI_SHAPE_CHECKBOX, 100, 30 _
)
comboShape = graphicInput_Create( _
    parentWindow, "combo_shape", GUI_SHAPE_COMBOBOX, 190, 30 _
)
listShape = graphicInput_Create( _
    parentWindow, "list_shape", GUI_SHAPE_LISTBOX, 280, 30 _
)
editShape = graphicInput_Create( _
    parentWindow, "edit_shape", GUI_SHAPE_EDITBOX, 370, 30 _
)
calendarShape = graphicInput_Create( _
    parentWindow, "calendar_shape", GUI_SHAPE_CALENDAR, 460, 30 _
)
radioShape = graphicInput_Create( _
    parentWindow, "radio_shape", GUI_SHAPE_RADIO_BUTTON_GROUP, 10, 100 _
)
controlShape = graphicInput_Create( _
    parentWindow, "control_shape", GUI_SHAPE_CONTROL, 100, 100 _
)
trendShape = graphicInput_Create( _
    parentWindow, "trend_shape", GUI_SHAPE_TREND_CONTROL, 190, 100 _
)
alarmShape = graphicInput_Create( _
    parentWindow, "alarm_shape", GUI_SHAPE_ALARM_CLIENT, 280, 100 _
)
dateShape = graphicInput_Create( _
    parentWindow, "date_shape", GUI_SHAPE_DATE_TIME_PICKER, 370, 100 _
)

If buttonShape = 0 OrElse checkboxShape = 0 OrElse comboShape = 0 OrElse _
   listShape = 0 OrElse editShape = 0 OrElse calendarShape = 0 OrElse _
   radioShape = 0 OrElse controlShape = 0 OrElse trendShape = 0 OrElse _
   alarmShape = 0 OrElse dateShape = 0 Then
    graphicInput_Fail "control allocation failed", 1
End If

For itemIndex As Integer = 0 To 2
    graphicshape_AddItem comboShape, "Combo " & itemIndex
    graphicshape_AddItem listShape, "List " & itemIndex
    graphicshape_AddItem radioShape, "Radio " & itemIndex
    graphicshape_AddItem alarmShape, "Alarm " & itemIndex
    graphicshape_AddItem dateShape, "Date " & itemIndex
Next itemIndex
graphicshape_SetText editShape, "Edit "
gui_UpdateAll

If graphicshape_IsInteractive(buttonShape) = 0 Then
    graphicInput_Fail "interactive state was not enabled", 2
End If

graphicInput_Click buttonShape
If graphicshape_GetChangeCount(buttonShape) <> 1 Then
    graphicInput_Fail "button activation was not reported", 3
End If

graphicInput_Click checkboxShape
If graphicshape_GetValue(checkboxShape) = 0 Then
    graphicInput_Fail "checkbox did not toggle", 4
End If

graphicInput_Click comboShape
comboData = Cast(GraphicShapeData Ptr, comboShape->data)
If graphicshape_IsDropdownOpen(comboShape) = 0 OrElse _
   comboData->dropdown_widget = 0 OrElse _
   comboData->dropdown_widget->h <= comboShape->h Then
    graphicInput_Fail "combo did not display its option list", 5
End If

graphicInput_Click comboData->dropdown_widget, 5, 27
If graphicshape_GetSelectedIndex(comboShape) <> 1 OrElse _
   graphicshape_GetSelectedItem(comboShape) <> "Combo 1" OrElse _
   graphicshape_IsDropdownOpen(comboShape) <> 0 Then
    graphicInput_Fail "combo option selection did not close the list", 5
End If

graphicInput_Click listShape, listShape->w \ 2, listShape->h - 2
If graphicshape_GetSelectedIndex(listShape) <> 2 Then
    graphicInput_Fail "list pointer selection was wrong", 6
End If

input_MockMouse listShape->ax + 5, listShape->ay + 5, 0, 1
gui_UpdateAll
If graphicshape_GetSelectedIndex(listShape) <> 1 Then
    graphicInput_Fail "list wheel selection was wrong", 7
End If

graphicInput_Click editShape
input_MockText "OK"
gui_UpdateAll
If graphicshape_GetText(editShape) <> "Edit OK" Then
    graphicInput_Fail "edit control ignored typed text", 8
End If

graphicInput_Click calendarShape, calendarShape->w - 2, _
    calendarShape->h - 2
If graphicshape_GetValue(calendarShape) <> 31 Then
    graphicInput_Fail "calendar did not select a day", 9
End If

graphicInput_Click radioShape, radioShape->w \ 2, radioShape->h - 2
If graphicshape_GetSelectedIndex(radioShape) <> 2 Then
    graphicInput_Fail "radio group selection was wrong", 10
End If

graphicInput_Click controlShape, (controlShape->w * 3) \ 4, _
    controlShape->h \ 2
If graphicshape_GetValue(controlShape) < 70 OrElse _
   graphicshape_GetValue(controlShape) > 80 Then
    graphicInput_Fail "generic control value was wrong", 11
End If

graphicInput_Click trendShape, trendShape->w \ 4, trendShape->h \ 2
If graphicshape_GetValue(trendShape) < 20 OrElse _
   graphicshape_GetValue(trendShape) > 30 Then
    graphicInput_Fail "trend marker value was wrong", 12
End If

graphicInput_Click alarmShape, alarmShape->w \ 2, alarmShape->h - 2
If graphicshape_GetSelectedIndex(alarmShape) <> 2 Then
    graphicInput_Fail "alarm row selection was wrong", 13
End If

graphicInput_Click dateShape
dateData = Cast(GraphicShapeData Ptr, dateShape->data)
If graphicshape_IsDropdownOpen(dateShape) = 0 OrElse _
   dateData->dropdown_widget = 0 Then
    graphicInput_Fail "date picker did not display its option list", 14
End If

graphicInput_Click dateData->dropdown_widget, 5, 27
If graphicshape_GetSelectedItem(dateShape) <> "Date 1" OrElse _
   graphicshape_IsDropdownOpen(dateShape) <> 0 Then
    graphicInput_Fail "date option selection did not close the list", 14
End If

graphicInput_Click dateShape
input_MockMouse 5, 5, 1
gui_UpdateAll
input_MockMouse 5, 5, 0
gui_UpdateAll
If graphicshape_IsDropdownOpen(dateShape) <> 0 Then
    graphicInput_Fail "outside click did not dismiss date options", 14
End If

If graphicInputChangeCount < 11 Then
    graphicInput_Fail "application callbacks missed input changes", 15
End If

gui_ResetForTest
backend_Exit
Print "graphic shape input smoke OK"
End 0

/' end of graphicshape_input_smoke.bas '/

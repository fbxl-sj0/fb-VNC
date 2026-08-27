/'
    Project: omaGUI
    ---------------

    File: perf_test.bas

    Purpose:

        Measure update and render cost for a large generated widget tree.

    Responsibilities:

        - construct a deep parent hierarchy
        - populate it through the generated-widget fast path
        - report average frame processing time over repeated passes

    This file intentionally does NOT contain:

        - correctness assertions
        - native input or resize benchmarking
        - long-term performance baselines
'/

#Lang "fb"

#define OMAGUI_IMPLEMENTATION
#include once "omaGUI.bi"

Print "omaGUI Massive Benchmark & Profiling"
backend_Init(800, 600, 1) ' Headless
gui_Init()

Const WIDGET_COUNT = 500

' Create a deep hierarchy of subwindows
Dim As Widget Ptr current_parent = 0
For i As Integer = 1 To 10
    Dim As String nm = "win_" & i
    Dim As Widget Ptr win = subwindow_Create(nm, "Window " & i, 10, 10, 700 - i*20, 500 - i*20)
    gui_AddGeneratedWidget(win)
    If current_parent <> 0 Then gui_SetParent(win, current_parent)
    current_parent = win
Next i

' Fill the last window with lots of every widget
For i As Integer = 1 To WIDGET_COUNT
    Dim As Widget Ptr b = button_Create("btn_" & i, "B" & i, i Mod 100, i Mod 100, 40, 20)
    gui_AddGeneratedWidget(b) : gui_SetParent(b, current_parent)

    Dim As Widget Ptr l = label_Create("lbl_" & i, "L" & i, (i*10) Mod 600, (i*10) Mod 400, RGB(0,0,0))
    gui_AddGeneratedWidget(l) : gui_SetParent(l, current_parent)

    Dim As Widget Ptr c = checkbox_Create("chk_" & i, "C" & i, (i*20) Mod 600, (i*20) Mod 400, i Mod 2)
    gui_AddGeneratedWidget(c) : gui_SetParent(c, current_parent)

    Dim As Widget Ptr r = radiobox_Create("rad_" & i, "R" & i, (i*30) Mod 600, (i*30) Mod 400, i \ 10, i Mod 2)
    gui_AddGeneratedWidget(r) : gui_SetParent(r, current_parent)

    Dim As Widget Ptr s = scrollbar_Create("sb_" & i, (i*40) Mod 600, (i*40) Mod 400, 100, 20, 100, 10, 0)
    gui_AddGeneratedWidget(s) : gui_SetParent(s, current_parent)

    Dim As Widget Ptr t = textbox_Create("tb_" & i, "T" & i, (i*50) Mod 600, (i*50) Mod 400, 80, 25, 0, 0)
    gui_AddGeneratedWidget(t) : gui_SetParent(t, current_parent)

    Dim As Widget Ptr g = graphicshape_Create("shp_" & i, GUI_SHAPE_ROUNDED_RECTANGLE, (i*60) Mod 600, (i*60) Mod 400, 30, 30, RGB(0,0,0), RGB(100,100,100), 1, "")
    gui_AddGeneratedWidget(g) : gui_SetParent(g, current_parent)
Next i

Print "Starting 1000 render passes..."
Dim As Double tStart = Timer
For i As Integer = 1 To 1000
    gui_UpdateAll()
    gui_RenderAll()
Next i
Dim As Double tEnd = Timer

Print "Avg time per frame (Update+Render): " & ((tEnd - tStart) / 1000.0) * 1000.0 & " ms"

backend_Exit()
Print "Benchmark finished."

/' end of perf_test.bas '/

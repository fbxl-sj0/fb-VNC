/'
    Project: omaGUI
    ---------------

    File: omaGUI.bi

    Purpose:

        Provide the public omaGUI declarations and, when selected by one
        program source file, compile the complete omaGUI implementation.

    Responsibilities:

        - expose all omaGUI backend and widget declarations
        - prevent duplicate declarations through a single include guard
        - assemble implementation units when OMAGUI_IMPLEMENTATION is defined

    This file intentionally does NOT contain:

        - application-specific GUI layout
        - editor state or game rules
        - platform-specific behavior outside omaGUI backend modules
'/

#ifndef __OMAGUI_BI__
#define __OMAGUI_BI__

' --- HEADERS ---
#include once "src/backend/backend.bi"
#include once "src/backend/input.bi"
#include once "src/backend/theme.bi"
#include once "src/backend/clipboard.bi"
#include once "src/backend/font_data.bi"

#include once "src/widgets/widgets.bi"
#include once "src/widgets/button.bi"
#include once "src/widgets/textbox.bi"
#include once "src/widgets/checkbox.bi"
#include once "src/widgets/radiobox.bi"
#include once "src/widgets/label.bi"
#include once "src/widgets/scrollbar.bi"
#include once "src/widgets/listbox.bi"
#include once "src/widgets/subwindow.bi"
#include once "src/widgets/filedialog.bi"
#include once "src/widgets/confirmdialog.bi"
#include once "src/widgets/menu.bi"
#include once "src/widgets/linewidget.bi"
#include once "src/widgets/rectwidget.bi"
#include once "src/widgets/circlewidget.bi"
#include once "src/widgets/curvewidget.bi"
#include once "src/widgets/graphicshape.bi"

' --- IMPLEMENTATIONS ---
' Only include implementations once per binary.
' Define OMAGUI_IMPLEMENTATION in ONE source file before including this.
#ifdef OMAGUI_IMPLEMENTATION
    ' This explicit one-binary implementation assembly is the omaGUI build model. FBLINT-ALLOW-BAS-INCLUDES
    #include once "src/backend/theme.bas"
    #include once "src/backend/font_data_full.bas"
    #include once "src/backend/backend_gfxlib.bas"
    #include once "src/backend/input_gfxlib.bas"
    #include once "src/backend/clipboard.bas"
    #include once "src/widgets/widgets.bas"
    #include once "src/widgets/button.bas"
    #include once "src/widgets/textbox.bas"
    #include once "src/widgets/textbox_history.bas"
    #include once "src/widgets/menu.bas"
    #include once "src/widgets/checkbox.bas"
    #include once "src/widgets/label.bas"
    #include once "src/widgets/scrollbar.bas"
    #include once "src/widgets/listbox.bas"
    #include once "src/widgets/subwindow.bas"
    #include once "src/widgets/filedialog.bas"
    #include once "src/widgets/confirmdialog.bas"
    #include once "src/widgets/radiobox.bas"
    #include once "src/widgets/linewidget.bas"
    #include once "src/widgets/rectwidget.bas"
    #include once "src/widgets/circlewidget.bas"
    #include once "src/widgets/curvewidget.bas"
    #include once "src/widgets/graphicshape.bas"
#endif

#endif
' end of omaGUI.bi

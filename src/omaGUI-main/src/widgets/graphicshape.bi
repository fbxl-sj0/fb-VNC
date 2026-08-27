/'
    Project: omaGUI
    ---------------

    File: graphicshape.bi

    Purpose:

        Generic lightweight graphic shape widget used by imported HMI
        graphics and simple drawing tools.

    Responsibilities:

        - define common shape kind identifiers
        - store style, point path, and label data for a primitive graphic element
        - expose a single creation API for imported graphics
        - expose a styled creation API for imported HMI graphics
        - expose opt-in input state for imported operator controls

    This file intentionally does NOT contain:

        - galaxy file parsing
        - animation evaluation
        - application-specific command handling
'/

#ifndef __GRAPHICSHAPE_BI__
#define __GRAPHICSHAPE_BI__

#include once "src/widgets/widgets.bi"

Const GUI_SHAPE_LINE As Integer = 1
Const GUI_SHAPE_RECTANGLE As Integer = 2
Const GUI_SHAPE_ROUNDED_RECTANGLE As Integer = 3
Const GUI_SHAPE_ELLIPSE As Integer = 4
Const GUI_SHAPE_POLYLINE As Integer = 5
Const GUI_SHAPE_POLYGON As Integer = 6
Const GUI_SHAPE_CURVE As Integer = 7
Const GUI_SHAPE_TEXT As Integer = 8
Const GUI_SHAPE_TEXTBOX As Integer = 9
Const GUI_SHAPE_BUTTON As Integer = 10
Const GUI_SHAPE_IMAGE As Integer = 11
Const GUI_SHAPE_ARC As Integer = 12
Const GUI_SHAPE_PIE As Integer = 13
Const GUI_SHAPE_CHORD As Integer = 14
Const GUI_SHAPE_CONNECTOR As Integer = 15
Const GUI_SHAPE_CONTROL As Integer = 16
Const GUI_SHAPE_CHECKBOX As Integer = 17
Const GUI_SHAPE_COMBOBOX As Integer = 18
Const GUI_SHAPE_LISTBOX As Integer = 19
Const GUI_SHAPE_EDITBOX As Integer = 20
Const GUI_SHAPE_CALENDAR As Integer = 21
Const GUI_SHAPE_DATE_TIME_PICKER As Integer = 22
Const GUI_SHAPE_RADIO_BUTTON_GROUP As Integer = 23
Const GUI_SHAPE_TREND_CONTROL As Integer = 24
Const GUI_SHAPE_TREND_PEN As Integer = 25
Const GUI_SHAPE_MULTI_PEN_TREND As Integer = 26
Const GUI_SHAPE_ALARM_CLIENT As Integer = 27
Const GUI_SHAPE_EMBEDDED_SYMBOL As Integer = 28

Const GRAPHICSHAPE_MAX_POINTS As Integer = 16
Const GRAPHICSHAPE_MAX_GRADIENT_STOPS As Integer = 8
Const GRAPHICSHAPE_DEFAULT_CORNER_RADIUS As Integer = 8
Const GRAPHICSHAPE_MAX_ITEMS As Integer = 16
Const GRAPHICSHAPE_MAX_INPUT_LENGTH As Integer = 256

Const GUI_FILL_SOLID As Integer = 0
Const GUI_FILL_GRADIENT_VERTICAL As Integer = 1
Const GUI_FILL_GRADIENT_HORIZONTAL As Integer = 2
Const GUI_FILL_GRADIENT_EDGE_HORIZONTAL As Integer = 3

Type GraphicShapeRenderOptions
    /'
        Render options are separated from the widget rectangle because imported
        HMI graphics keep accumulating independent drawing properties. New
        decoded fields should land here instead of growing another positional
        constructor with a long list of easy-to-swap arguments.
    '/

    As Integer shape_kind
    As ULong stroke_clr
    As ULong fill_clr
    As ULong fill_gradient_clr
    As ULong text_clr
    As Integer filled
    As Integer fill_mode
    As Integer line_width
    As Integer object_alpha
    As Integer stroke_alpha
    As Integer fill_alpha
    As Integer font_id
    As Integer text_h_align
    As Integer text_v_align
    As Integer text_fit_width
    As Integer corner_radius
    As Integer clip_to_bounds
    As Integer fill_gradient_stop_count
    As Integer fill_gradient_stop_pos(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS)
    As ULong fill_gradient_stop_clr(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS)
End Type

Type GraphicShapeData
    As Integer shape_kind
    As ULong stroke_clr
    As ULong fill_clr
    As ULong fill_gradient_clr
    As ULong text_clr
    As Integer filled
    As Integer fill_mode
    As Integer line_width
    As Integer object_alpha
    As Integer stroke_alpha
    As Integer fill_alpha
    As Integer font_id
    As Integer text_h_align
    As Integer text_v_align
    As Integer text_fit_width
    As Integer corner_radius
    As Integer clip_to_bounds
    As Integer fill_gradient_stop_count
    As Integer fill_gradient_stop_pos(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS)
    As ULong fill_gradient_stop_clr(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS)
    As Integer point_count
    As Integer point_x(1 To GRAPHICSHAPE_MAX_POINTS)
    As Integer point_y(1 To GRAPHICSHAPE_MAX_POINTS)
    As String label
    /'
        Imported controls are static by default. Applications can opt a shape
        into input without replacing its imported drawing properties. The
        callback receives the owning Widget pointer and reads the new state
        through the accessors below.
    '/
    As Integer interactive
    As Integer pressed, pointer_latch, key_latch
    As Integer value, selected_index, change_count
    As Integer item_count
    As String items(0 To GRAPHICSHAPE_MAX_ITEMS - 1)
    As Any Ptr change_handler
    As Widget Ptr dropdown_widget
End Type

Declare Sub graphicshape_DefaultOptions(ByRef options As GraphicShapeRenderOptions, ByVal shape_kind As Integer = GUI_SHAPE_RECTANGLE)
Declare Function graphicshape_CreateWithOptions( _
    ByVal nm As String, ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByRef options As GraphicShapeRenderOptions, ByVal label As String _
) As Widget Ptr
Declare Function graphicshape_Create( _
    ByVal nm As String, ByVal shape_kind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal stroke_clr As ULong, ByVal fill_clr As ULong, _
    ByVal filled As Integer, ByVal label As String _
) As Widget Ptr
Declare Function graphicshape_CreateStyled( _
    ByVal nm As String, ByVal shape_kind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal stroke_clr As ULong, ByVal fill_clr As ULong, _
    ByVal filled As Integer, ByVal line_width As Integer, _
    ByVal object_alpha As Integer, ByVal stroke_alpha As Integer, _
    ByVal fill_alpha As Integer, ByVal label As String _
) As Widget Ptr
Declare Function graphicshape_CreateStyledText( _
    ByVal nm As String, ByVal shape_kind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal stroke_clr As ULong, ByVal fill_clr As ULong, _
    ByVal filled As Integer, ByVal line_width As Integer, _
    ByVal object_alpha As Integer, ByVal stroke_alpha As Integer, _
    ByVal fill_alpha As Integer, ByVal label As String, _
    ByVal font_id As Integer, ByVal text_h_align As Integer, _
    ByVal text_v_align As Integer _
) As Widget Ptr
Declare Function graphicshape_CreateStyledTextColor( _
    ByVal nm As String, ByVal shape_kind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal stroke_clr As ULong, ByVal fill_clr As ULong, _
    ByVal text_clr As ULong, ByVal filled As Integer, _
    ByVal line_width As Integer, ByVal object_alpha As Integer, _
    ByVal stroke_alpha As Integer, ByVal fill_alpha As Integer, _
    ByVal label As String, ByVal font_id As Integer, _
    ByVal text_h_align As Integer, ByVal text_v_align As Integer _
) As Widget Ptr
Declare Function graphicshape_CreateStyledTextColorFit( _
    ByVal nm As String, ByVal shape_kind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal stroke_clr As ULong, ByVal fill_clr As ULong, _
    ByVal text_clr As ULong, ByVal filled As Integer, _
    ByVal line_width As Integer, ByVal object_alpha As Integer, _
    ByVal stroke_alpha As Integer, ByVal fill_alpha As Integer, _
    ByVal label As String, ByVal font_id As Integer, _
    ByVal text_h_align As Integer, ByVal text_v_align As Integer, _
    ByVal text_fit_width As Integer _
) As Widget Ptr
Declare Sub graphicshape_RenderWithOptions( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByRef options As GraphicShapeRenderOptions, ByVal label As String, _
    ByVal point_count As Integer, _
    point_x() As Integer, point_y() As Integer _
)
Declare Sub graphicshape_SetRenderOptions(ByVal w As Widget Ptr, ByRef options As GraphicShapeRenderOptions)
Declare Sub graphicshape_SetCornerRadius(ByVal w As Widget Ptr, ByVal corner_radius As Integer)
Declare Sub graphicshape_SetClipToBounds(ByVal w As Widget Ptr, ByVal clip_to_bounds As Integer)
Declare Sub graphicshape_SetObjectAlpha(ByVal w As Widget Ptr, ByVal object_alpha As Integer)
Declare Sub graphicshape_SetStrokeAlpha(ByVal w As Widget Ptr, ByVal stroke_alpha As Integer)
Declare Sub graphicshape_SetOutlineAlpha(ByVal w As Widget Ptr, ByVal outline_alpha As Integer)
Declare Sub graphicshape_SetFillAlpha(ByVal w As Widget Ptr, ByVal fill_alpha As Integer)
Declare Sub graphicshape_SetFillGradient(ByVal w As Widget Ptr, ByVal fill_mode As Integer, ByVal fill_gradient_clr As ULong)
Declare Sub graphicshape_SetFillGradientStops(ByVal w As Widget Ptr, ByVal stop_count As Integer, stop_pos() As Integer, stop_clr() As ULong)
Declare Sub graphicshape_SetPathPoint(ByVal w As Widget Ptr, ByVal point_index As Integer, ByVal point_x As Integer, ByVal point_y As Integer)
Declare Sub graphicshape_SetInteractive( _
    ByVal w As Widget Ptr, ByVal enabled As Integer, _
    ByVal change_handler As Any Ptr = 0 _
)
Declare Function graphicshape_IsInteractive(ByVal w As Widget Ptr) As Integer
Declare Sub graphicshape_SetValue(ByVal w As Widget Ptr, ByVal value As Integer)
Declare Function graphicshape_GetValue(ByVal w As Widget Ptr) As Integer
Declare Sub graphicshape_SetText(ByVal w As Widget Ptr, ByVal text As String)
Declare Function graphicshape_GetText(ByVal w As Widget Ptr) As String
Declare Sub graphicshape_ClearItems(ByVal w As Widget Ptr)
Declare Function graphicshape_AddItem( _
    ByVal w As Widget Ptr, ByVal item_text As String _
) As Integer
Declare Function graphicshape_GetSelectedIndex(ByVal w As Widget Ptr) As Integer
Declare Function graphicshape_GetSelectedItem(ByVal w As Widget Ptr) As String
Declare Function graphicshape_GetChangeCount(ByVal w As Widget Ptr) As Integer
Declare Function graphicshape_IsDropdownOpen(ByVal w As Widget Ptr) As Integer
Declare Sub graphicshape_Render(ByVal w As Widget Ptr)
Declare Sub graphicshape_Update(ByVal w As Widget Ptr)
Declare Sub graphicshape_Destroy(ByVal w As Widget Ptr)

#endif

/' end of graphicshape.bi '/

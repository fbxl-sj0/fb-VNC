/'
    Project: omaGUI
    ---------------
    File: backend.bi

    Purpose:
        Declare the gfxlib graphics, text, clipping, and window interface.

    Responsibilities:
        - configure fixed or resizable platform windows
        - configure true-color and balanced indexed-color display modes
        - report the live drawable area after a window resize
        - expose primitive and alpha-aware drawing operations
        - expose embedded-font measurement and rendering operations

    This file intentionally does NOT contain:
        - widget-specific behavior
        - input polling
        - application-specific layout rules
'/

#ifndef __BACKEND_BI__
#define __BACKEND_BI__

#include "fbgfx.bi"

#ifndef RGB
#define RGB(r,g,b) (((CUInt(r) And &hFF) Shl 16) Or ((CUInt(g) And &hFF) Shl 8) Or (CUInt(b) And &hFF))
#endif

#ifndef RGBA
#define RGBA(r,g,b,a) (((CUInt(a) And &hFF) Shl 24) Or ((CUInt(r) And &hFF) Shl 16) Or ((CUInt(g) And &hFF) Shl 8) Or (CUInt(b) And &hFF))
#endif

' -------------------------------------------------------------------------
' Text constants
' -------------------------------------------------------------------------

Const BACKEND_FONT_DEFAULT As Integer = 0
Const BACKEND_FONT_ARIAL_10_REGULAR As Integer = 1
Const BACKEND_FONT_ARIAL_12_BOLD As Integer = 2

Const BACKEND_ALIGN_LEFT As Integer = 0
Const BACKEND_ALIGN_CENTER As Integer = 1
Const BACKEND_ALIGN_RIGHT As Integer = 2

Const BACKEND_ALIGN_TOP As Integer = 0
Const BACKEND_ALIGN_MIDDLE As Integer = 1
Const BACKEND_ALIGN_BOTTOM As Integer = 2

' -------------------------------------------------------------------------
' Backend API
' -------------------------------------------------------------------------

Const BACKEND_WINDOW_FIXED As UInteger = 0
Const BACKEND_WINDOW_RESIZABLE As UInteger = 1
Const BACKEND_WINDOW_FULLSCREEN As UInteger = 2

Const BACKEND_COLOR_DEPTH_MONOCHROME As Integer = 1
Const BACKEND_COLOR_DEPTH_16_COLOR As Integer = 4
Const BACKEND_COLOR_DEPTH_256_COLOR As Integer = 8
Const BACKEND_COLOR_DEPTH_HIGH_COLOR As Integer = 16
Const BACKEND_COLOR_DEPTH_TRUE_COLOR As Integer = 32

Declare Sub backend_Init( _
    ByVal w As Integer, _
    ByVal h As Integer, _
    ByVal headless As Integer = 0, _
    ByVal windowFlags As UInteger = BACKEND_WINDOW_FIXED, _
    ByVal colorDepth As Integer = BACKEND_COLOR_DEPTH_TRUE_COLOR _
)
Declare Sub backend_Exit()
/'
    Recreate both gfx pages while changing between fixed, resizable, and
    full-screen modes. The function returns zero when gfxlib rejects the mode.
'/
Declare Function backend_SetWindowMode( _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal windowFlags As UInteger _
) As Integer
Declare Sub backend_GetSize(ByRef w As Integer, ByRef h As Integer)
Declare Function backend_IsResizable() As Integer
Declare Function backend_GetColorDepth() As Integer
Declare Function backend_SetColorDepth(ByVal colorDepth As Integer) As Integer

Declare Sub backend_Clear(ByVal clr As ULong = 0)
Declare Sub backend_Flip()

Declare Sub backend_Rect(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, ByVal filled As Integer = 0)
Declare Sub backend_Line(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal clr As ULong)
Declare Sub backend_LineEx(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal clr As ULong, ByVal line_width As Integer = 1, ByVal alpha As Integer = 255)
Declare Sub backend_RectEx(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, ByVal filled As Integer = 0, ByVal line_width As Integer = 1, ByVal alpha As Integer = 255)
Declare Sub backend_PSet(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong)
Declare Sub backend_PSetAlpha(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal alpha As Integer)
Declare Sub backend_Circle(ByVal x As Integer, ByVal y As Integer, ByVal r As Integer, ByVal clr As ULong, ByVal filled As Integer = 0)
Declare Sub backend_Curve(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal x3 As Integer, ByVal y3 As Integer, ByVal clr As ULong)

Declare Sub backend_Print(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal text As String)
Declare Sub backend_PrintScaled(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal text As String, ByVal scale_x As Integer = 1, ByVal scale_y As Integer = 1)
Declare Sub backend_PrintFont(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal text As String, ByVal font_id As Integer)
Declare Sub backend_PrintFontAlpha(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal text As String, ByVal font_id As Integer, ByVal alpha As Integer)
Declare Sub backend_PrintScaledFont(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal text As String, ByVal font_id As Integer, ByVal scale_x As Integer = 1, ByVal scale_y As Integer = 1)
Declare Sub backend_PrintScaledFontAlpha( _
    ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, _
    ByVal text As String, ByVal font_id As Integer, _
    ByVal scale_x As Integer = 1, ByVal scale_y As Integer = 1, _
    ByVal alpha As Integer = 255 _
)
Declare Sub backend_PrintAligned( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, _
    ByVal text As String, ByVal font_id As Integer = BACKEND_FONT_DEFAULT, _
    ByVal horizontal_align As Integer = BACKEND_ALIGN_LEFT, _
    ByVal vertical_align As Integer = BACKEND_ALIGN_TOP _
)
Declare Sub backend_PrintAlignedAlpha( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, _
    ByVal text As String, ByVal font_id As Integer = BACKEND_FONT_DEFAULT, _
    ByVal horizontal_align As Integer = BACKEND_ALIGN_LEFT, _
    ByVal vertical_align As Integer = BACKEND_ALIGN_TOP, _
    ByVal alpha As Integer = 255 _
)
Declare Sub backend_PrintAlignedScaled( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, _
    ByVal text As String, ByVal font_id As Integer = BACKEND_FONT_DEFAULT, _
    ByVal horizontal_align As Integer = BACKEND_ALIGN_LEFT, _
    ByVal vertical_align As Integer = BACKEND_ALIGN_TOP, _
    ByVal scale_x As Integer = 1, ByVal scale_y As Integer = 1 _
)
Declare Sub backend_PrintAlignedScaledAlpha( _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, _
    ByVal text As String, ByVal font_id As Integer = BACKEND_FONT_DEFAULT, _
    ByVal horizontal_align As Integer = BACKEND_ALIGN_LEFT, _
    ByVal vertical_align As Integer = BACKEND_ALIGN_TOP, _
    ByVal scale_x As Integer = 1, ByVal scale_y As Integer = 1, _
    ByVal alpha As Integer = 255 _
)
Declare Function backend_GetTextWidth(ByVal text As String) As Integer
Declare Function backend_GetTextWidthScaled(ByVal text As String, ByVal scale_x As Integer = 1) As Integer
Declare Function backend_GetTextWidthFont(ByVal text As String, ByVal font_id As Integer) As Integer
Declare Function backend_GetTextWidthScaledFont(ByVal text As String, ByVal font_id As Integer, ByVal scale_x As Integer = 1) As Integer
Declare Function backend_GetTextHeight() As Integer
Declare Function backend_GetTextHeightScaled(ByVal scale_y As Integer = 1) As Integer
Declare Function backend_GetTextHeightFont(ByVal font_id As Integer) As Integer
Declare Function backend_GetTextHeightScaledFont(ByVal font_id As Integer, ByVal scale_y As Integer = 1) As Integer

Declare Sub backend_SetClip(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer)
Declare Sub backend_ResetClip()

Declare Sub backend_SaveSnapshot(ByVal filename As String)

#endif

' end of backend.bi

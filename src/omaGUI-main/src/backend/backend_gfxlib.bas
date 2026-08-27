/'
    Project: omaGUI
    ---------------
    File: backend_gfxlib.bas

    Purpose:
        Implement omaGUI drawing and window management with FreeBASIC gfxlib.

    Responsibilities:
        - create fixed or resizable double-buffered gfxlib screens
        - recreate those screens when an application changes window mode
        - configure predictable palettes for indexed-color modes
        - report the live drawable size to reactive GUI layouts
        - swap complete pages at the display refresh boundary
        - draw primitives and alpha-mapped embedded fonts

    This file intentionally does NOT contain:
        - widget layout or input dispatch
        - application-specific rendering
'/

#lang "fb"

#include once "src/backend/backend.bi"
#include once "src/backend/font_data.bi"
#include once "src/backend/theme.bi"
#Ifdef __FB_GFXLIB3__
#include once "fbgfx3.bi"
#EndIf

Const BACKEND_GFX_VISIBLE_PAGE As Integer = 0
Const BACKEND_GFX_WORK_PAGE As Integer = 1
Const BACKEND_GFX_PAGE_COUNT As Integer = 2
Const BACKEND_CURVE_STEP As Double = 0.05
Const BACKEND_8BIT_COLOR_CUBE_SIZE As Integer = 216
Const BACKEND_8BIT_GRAY_COUNT As Integer = 40
Const BACKEND_8BIT_GRAY_THRESHOLD As Integer = 18
Const BACKEND_CLIP_STACK_CAPACITY As Integer = 128
#Ifdef __FB_GFXLIB3__
/'
    Bound temporary glyph packets so an unexpectedly long label cannot make
    the UI allocate an arbitrary amount of memory. Larger text retains the
    established pixel renderer as a correctness fallback.
'/
Const BACKEND_GFX3_TEXT_POINT_LIMIT As ULongInt = 262144

Private Function backend_Gfx3Alpha( _
    ByVal alpha As Integer _
) As ULong
    If alpha <= 0 Then Return 0
    If alpha >= 255 Then Return 255

    /'
        gfxlib alpha primitives divide by 256, while omaGUI's established
        software renderer divides by 255. Advancing a partial alpha value by
        one preserves the closest integer result without changing transparent
        or opaque pixels. Channel rounding can still differ by at most one.
    '/
    Return CULng(alpha + 1)
End Function
#EndIf

/'
    Backend-local module state

    The backend runtime owns this fixed-capacity state. It has static lifetime
    because independent drawing entry points share one active gfxlib screen.
    No widget or application code mutates it directly.
'/
Dim Shared backend_DoubleBufferActive As Integer
Dim Shared backend_GfxWorkPage As Integer
Dim Shared backend_GfxVisiblePage As Integer
Dim Shared backend_Resizable As Integer
Dim Shared backend_RequestedWidth As Integer
Dim Shared backend_RequestedHeight As Integer
Dim Shared backend_WindowFlags As UInteger
Dim Shared backend_ColorDepth As Integer
Dim Shared backend_ClipDepth As Integer
Dim Shared backend_ClipOverflowDepth As Integer
Dim Shared backend_ClipX1(0 To BACKEND_CLIP_STACK_CAPACITY - 1) As Integer
Dim Shared backend_ClipY1(0 To BACKEND_CLIP_STACK_CAPACITY - 1) As Integer
Dim Shared backend_ClipX2(0 To BACKEND_CLIP_STACK_CAPACITY - 1) As Integer
Dim Shared backend_ClipY2(0 To BACKEND_CLIP_STACK_CAPACITY - 1) As Integer

' -------------------------------------------------------------------------
' Helpers: Screen configuration
' -------------------------------------------------------------------------

Private Function backend_IsSupportedColorDepth( _
    ByVal colorDepth As Integer _
) As Integer

    Select Case colorDepth
    Case BACKEND_COLOR_DEPTH_MONOCHROME, _
         BACKEND_COLOR_DEPTH_16_COLOR, _
         BACKEND_COLOR_DEPTH_256_COLOR, _
         BACKEND_COLOR_DEPTH_HIGH_COLOR, _
         BACKEND_COLOR_DEPTH_TRUE_COLOR
        Return -1
    End Select

    Return 0
End Function


Private Sub backend_Get16ColorPaletteEntry( _
    ByVal colorIndex As Integer, _
    ByRef redValue As Integer, _
    ByRef greenValue As Integer, _
    ByRef blueValue As Integer _
)

    /'
        The 16-color mode uses the conventional VGA palette. In particular,
        color 0 is black and color 15 is white, so low-depth applications get
        stable results instead of depending on a platform driver palette.
    '/
    Select Case colorIndex
    Case 0  : redValue = 0   : greenValue = 0   : blueValue = 0
    Case 1  : redValue = 0   : greenValue = 0   : blueValue = 170
    Case 2  : redValue = 0   : greenValue = 170 : blueValue = 0
    Case 3  : redValue = 0   : greenValue = 170 : blueValue = 170
    Case 4  : redValue = 170 : greenValue = 0   : blueValue = 0
    Case 5  : redValue = 170 : greenValue = 0   : blueValue = 170
    Case 6  : redValue = 170 : greenValue = 85  : blueValue = 0
    Case 7  : redValue = 170 : greenValue = 170 : blueValue = 170
    Case 8  : redValue = 85  : greenValue = 85  : blueValue = 85
    Case 9  : redValue = 85  : greenValue = 85  : blueValue = 255
    Case 10 : redValue = 85  : greenValue = 255 : blueValue = 85
    Case 11 : redValue = 85  : greenValue = 255 : blueValue = 255
    Case 12 : redValue = 255 : greenValue = 85  : blueValue = 85
    Case 13 : redValue = 255 : greenValue = 85  : blueValue = 255
    Case 14 : redValue = 255 : greenValue = 255 : blueValue = 85
    Case Else
        redValue = 255 : greenValue = 255 : blueValue = 255
    End Select
End Sub


Private Sub backend_ConfigureIndexedPalette(ByVal colorDepth As Integer)
    Dim As Integer colorIndex
    Dim As Integer redValue
    Dim As Integer greenValue
    Dim As Integer blueValue

    Select Case colorDepth
    Case BACKEND_COLOR_DEPTH_MONOCHROME
        Palette 0, 0, 0, 0
        Palette 1, 255, 255, 255

    Case BACKEND_COLOR_DEPTH_16_COLOR
        For colorIndex = 0 To 15
            backend_Get16ColorPaletteEntry _
                colorIndex, redValue, greenValue, blueValue
            Palette colorIndex, redValue, greenValue, blueValue
        Next colorIndex

    Case BACKEND_COLOR_DEPTH_256_COLOR
        /'
            The first 216 entries form a 6 x 6 x 6 RGB cube. The remaining 40
            entries form a grayscale ramp. The dedicated ramp prevents neutral
            GUI colors from taking on the blue or green cast common to 3:3:2
            palettes while retaining a useful range of saturated colors.
        '/
        For colorIndex = 0 To BACKEND_8BIT_COLOR_CUBE_SIZE - 1
            redValue = (colorIndex \ 36) * 51
            greenValue = ((colorIndex \ 6) Mod 6) * 51
            blueValue = (colorIndex Mod 6) * 51
            Palette colorIndex, redValue, greenValue, blueValue
        Next colorIndex

        For colorIndex = 0 To BACKEND_8BIT_GRAY_COUNT - 1
            redValue = (colorIndex * 255) \ _
                (BACKEND_8BIT_GRAY_COUNT - 1)
            Palette BACKEND_8BIT_COLOR_CUBE_SIZE + colorIndex, _
                redValue, redValue, redValue
        Next colorIndex
    End Select
End Sub


Private Function backend_CreateScreen( _
    ByVal w As Integer, _
    ByVal h As Integer, _
    ByVal windowFlags As UInteger, _
    ByVal colorDepth As Integer _
) As Integer

    Dim As Integer actualDepth
    Dim As Integer actualHeight
    Dim As Integer actualWidth
    Dim As Integer screenResult
    Dim As UInteger gfxFlags

    If w < 1 OrElse h < 1 Then Return 0
    If backend_IsSupportedColorDepth(colorDepth) = 0 Then Return 0

    gfxFlags = 0
    If (windowFlags And BACKEND_WINDOW_RESIZABLE) <> 0 Then
        gfxFlags Or= FB.GFX_RESIZABLE
    End If
    If (windowFlags And BACKEND_WINDOW_FULLSCREEN) <> 0 Then
        gfxFlags Or= FB.GFX_FULLSCREEN
    End If

    screenResult = ScreenRes( _
        w, h, colorDepth, BACKEND_GFX_PAGE_COUNT, gfxFlags _
    )

    If screenResult <> 0 Then
        screenResult = ScreenRes( _
            w, h, colorDepth, BACKEND_GFX_PAGE_COUNT, _
            gfxFlags Or FB.GFX_NO_SWITCH _
        )
    End If

    If screenResult <> 0 Then Return 0

    ScreenSet BACKEND_GFX_WORK_PAGE, BACKEND_GFX_VISIBLE_PAGE
    ScreenInfo actualWidth, actualHeight, actualDepth

    backend_GfxWorkPage = BACKEND_GFX_WORK_PAGE
    backend_GfxVisiblePage = BACKEND_GFX_VISIBLE_PAGE
    backend_DoubleBufferActive = -1
    backend_Resizable = IIf( _
        (windowFlags And BACKEND_WINDOW_RESIZABLE) <> 0, -1, 0 _
    )
    backend_RequestedWidth = w
    backend_RequestedHeight = h
    backend_WindowFlags = windowFlags
    backend_ColorDepth = actualDepth
    backend_ClipDepth = 0
    backend_ClipOverflowDepth = 0
    backend_ConfigureIndexedPalette actualDepth

    Return -1
End Function

' -------------------------------------------------------------------------
' Helpers: Degraded Color Mapping
' -------------------------------------------------------------------------
Private Function MapColor(ByVal clr As ULong) As ULong
    Dim As Integer w, h, d, bpp, pitch
    ScreenInfo w, h, d, bpp, pitch
    If d >= 16 Then Return clr

    Dim As UByte r = (clr Shr 16) And &HFF
    Dim As UByte g = (clr Shr 8) And &HFF
    Dim As UByte b = clr And &HFF

    If d = BACKEND_COLOR_DEPTH_256_COLOR Then
        Dim As Integer highestChannel = r
        Dim As Integer lowestChannel = r
        Dim As UInteger luminance

        If g > highestChannel Then highestChannel = g
        If b > highestChannel Then highestChannel = b
        If g < lowestChannel Then lowestChannel = g
        If b < lowestChannel Then lowestChannel = b

        If highestChannel - lowestChannel <= BACKEND_8BIT_GRAY_THRESHOLD Then
            luminance = (CUInt(r) * 299) + (CUInt(g) * 587) + _
                (CUInt(b) * 114)
            Return BACKEND_8BIT_COLOR_CUBE_SIZE + _
                (((luminance \ 1000) * _
                (BACKEND_8BIT_GRAY_COUNT - 1)) + 127) \ 255
        End If

        Return (((CUInt(r) * 5) + 127) \ 255) * 36 + _
            (((CUInt(g) * 5) + 127) \ 255) * 6 + _
            (((CUInt(b) * 5) + 127) \ 255)
    Elseif d = BACKEND_COLOR_DEPTH_16_COLOR Then
        Dim As Integer colorIndex
        Dim As Integer paletteRed
        Dim As Integer paletteGreen
        Dim As Integer paletteBlue
        Dim As LongInt redDistance
        Dim As LongInt greenDistance
        Dim As LongInt blueDistance
        Dim As LongInt colorDistance
        Dim As LongInt nearestDistance = &H7FFFFFFF
        Dim As Integer nearestIndex

        For colorIndex = 0 To 15
            backend_Get16ColorPaletteEntry _
                colorIndex, paletteRed, paletteGreen, paletteBlue
            redDistance = CInt(r) - paletteRed
            greenDistance = CInt(g) - paletteGreen
            blueDistance = CInt(b) - paletteBlue
            colorDistance = (redDistance * redDistance) + _
                (greenDistance * greenDistance) + _
                (blueDistance * blueDistance)

            If colorDistance < nearestDistance Then
                nearestDistance = colorDistance
                nearestIndex = colorIndex
            End If
        Next colorIndex

        Return nearestIndex
    Elseif d = BACKEND_COLOR_DEPTH_MONOCHROME Then
        /'
            ITU-R BT.601 luma weights provide a more faithful black/white
            threshold than adding the channels with equal importance.
        '/
        Return IIf( _
            (CUInt(r) * 299) + (CUInt(g) * 587) + (CUInt(b) * 114) >= 128000, _
            1, 0 _
        )
    End If
    Return clr
End Function

' -------------------------------------------------------------------------
' Lifecycle
' -------------------------------------------------------------------------

Sub backend_Init( _
    ByVal w As Integer, _
    ByVal h As Integer, _
    ByVal headless As Integer, _
    ByVal windowFlags As UInteger, _
    ByVal colorDepth As Integer _
)

    /'
        The headless flag remains part of the public API for deterministic
        tests. gfxlib still needs a software screen as their draw target, so
        both paths share the same screen creation and renderer setup.
    '/
    backend_DoubleBufferActive = 0
    backend_GfxWorkPage = BACKEND_GFX_VISIBLE_PAGE
    backend_GfxVisiblePage = BACKEND_GFX_VISIBLE_PAGE
    backend_Resizable = 0
    backend_RequestedWidth = w
    backend_RequestedHeight = h
    backend_WindowFlags = windowFlags
    backend_ColorDepth = 0

    If backend_CreateScreen(w, h, windowFlags, colorDepth) = 0 Then
        /'
            A caller may request a low-depth mode that the active driver does
            not implement. Preserve the historical guarantee that backend_Init
            still provides a usable screen by falling back to 32-bit color.
        '/
        backend_CreateScreen _
            w, h, windowFlags, BACKEND_COLOR_DEPTH_TRUE_COLOR
    End If

    font_init_pointers()
    theme_InitClassic()
End Sub

Sub backend_Exit()
    backend_DoubleBufferActive = 0
    backend_GfxWorkPage = BACKEND_GFX_VISIBLE_PAGE
    backend_GfxVisiblePage = BACKEND_GFX_VISIBLE_PAGE
    backend_Resizable = 0
    backend_ColorDepth = 0
    backend_ClipDepth = 0
    backend_ClipOverflowDepth = 0
End Sub


Function backend_SetWindowMode( _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal windowFlags As UInteger _
) As Integer
    /'
        Reuse the same guarded creation path as initialization so both pages,
        the work/visible selection, clipping state, and live-size fallback are
        reset together after a windowed/full-screen transition.
    '/
    Return backend_CreateScreen(w, h, windowFlags, backend_ColorDepth)
End Function

Sub backend_GetSize(ByRef w As Integer, ByRef h As Integer)
    w = 0
    h = 0
    ScreenInfo w, h

    If w <= 0 Then w = backend_RequestedWidth
    If h <= 0 Then h = backend_RequestedHeight
End Sub

Function backend_IsResizable() As Integer
    Return backend_Resizable
End Function


Function backend_GetColorDepth() As Integer
    Dim As Integer actualDepth
    Dim As Integer actualHeight
    Dim As Integer actualWidth

    ScreenInfo actualWidth, actualHeight, actualDepth
    If actualDepth > 0 Then backend_ColorDepth = actualDepth

    Return backend_ColorDepth
End Function


Function backend_SetColorDepth(ByVal colorDepth As Integer) As Integer
    Dim As Integer currentHeight
    Dim As Integer currentWidth
    Dim As Integer oldDepth

    If backend_IsSupportedColorDepth(colorDepth) = 0 Then Return 0

    oldDepth = backend_GetColorDepth()
    If oldDepth = colorDepth Then Return -1

    backend_GetSize currentWidth, currentHeight
    If backend_CreateScreen( _
        currentWidth, currentHeight, backend_WindowFlags, colorDepth _
    ) Then
        Return -1
    End If

    /'
        ScreenRes may discard the old display before reporting a driver error.
        Make a best effort to restore the last working mode before returning.
    '/
    If oldDepth > 0 Then
        backend_CreateScreen _
            currentWidth, currentHeight, backend_WindowFlags, oldDepth
    End If

    Return 0
End Function

' -------------------------------------------------------------------------
' Rendering
' -------------------------------------------------------------------------

Sub backend_Clear(ByVal clr As ULong)
    Dim As Integer screen_w
    Dim As Integer screen_h

    ScreenInfo screen_w, screen_h

    If screen_w <= 0 Then screen_w = 800
    If screen_h <= 0 Then screen_h = 600

    backend_Rect(0, 0, screen_w, screen_h, clr, 1)
End Sub

Sub backend_Flip()
    If backend_DoubleBufferActive = 0 Then Exit Sub

    /'
        ScreenSet selects separate work and visible pages. Exchanging them at
        the refresh boundary presents only complete frames and avoids copying
        a full framebuffer after every render pass.

        gfxlib3 queues presentation when ScreenSet changes the visible page.
        Calling ScreenSync first creates a second presentation boundary and
        reduces a nominal 60 Hz VNC workload to approximately 30 page changes
        per second. The older gfxlib requires ScreenSync before the page swap.
    '/
#Ifndef __FB_GFXLIB3__
    ScreenSync
#EndIf
    backend_GfxVisiblePage = backend_GfxWorkPage

    If backend_GfxWorkPage = BACKEND_GFX_VISIBLE_PAGE Then
        backend_GfxWorkPage = BACKEND_GFX_WORK_PAGE
    Else
        backend_GfxWorkPage = BACKEND_GFX_VISIBLE_PAGE
    End If

    ScreenSet backend_GfxWorkPage, backend_GfxVisiblePage
End Sub

Sub backend_Rect(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal clr As ULong, ByVal filled As Integer)
    If filled Then : Line (x, y)-(x + w - 1, y + h - 1), MapColor(clr), BF : Else : Line (x, y)-(x + w - 1, y + h - 1), MapColor(clr), B : End If
End Sub

Sub backend_Line(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal clr As ULong)
    Line (x1, y1)-(x2, y2), MapColor(clr)
End Sub

Sub backend_PSetAlpha(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal alpha As Integer)
    Dim As Integer screen_w
    Dim As Integer screen_h
    Dim As Integer screen_d
    Dim As ULong bg
    Dim As ULong r
    Dim As ULong g
    Dim As ULong b
    Dim As ULong br
    Dim As ULong bg_g
    Dim As ULong bb
    Dim As ULong rr
    Dim As ULong rg
    Dim As ULong rb

    If alpha <= 0 Then Exit Sub

    ScreenInfo screen_w, screen_h, screen_d

    If x < 0 Or y < 0 Or x >= screen_w Or y >= screen_h Then
        Exit Sub
    End If

    If alpha >= 255 Or screen_d < 16 Then
        PSet (x, y), MapColor(clr)
        Exit Sub
    End If

#Ifdef __FB_GFXLIB3__
    /'
        A gfxlib3 page is normally authoritative on the GPU. POINT would
        download that complete page before blending one pixel, which is
        especially expensive after an application has drawn a scaled surface.
        The extension preserves gfxlib's alpha arithmetic in the queued GPU
        command and therefore does not cross the CPU/GPU ownership boundary.
    '/
    If screen_d = 32 Then
        Dim As fb.Gfx3Point gpu_point

        gpu_point.x = x
        gpu_point.y = y
        gpu_point.color = clr
        gpu_point.alpha = backend_Gfx3Alpha(alpha)

        If fb.Gfx3DrawPoints(0, @gpu_point, 1) = 0 Then
            Exit Sub
        End If
    End If
#EndIf

    bg = Point(x, y)

    r = (clr Shr 16) And &HFF
    g = (clr Shr 8) And &HFF
    b = clr And &HFF

    br = (bg Shr 16) And &HFF
    bg_g = (bg Shr 8) And &HFF
    bb = bg And &HFF

    rr = ((r * alpha) + (br * (255 - alpha))) \ 255
    rg = ((g * alpha) + (bg_g * (255 - alpha))) \ 255
    rb = ((b * alpha) + (bb * (255 - alpha))) \ 255

    PSet (x, y), RGB(rr, rg, rb)
End Sub

Private Sub backend_DrawLineAlpha(ByVal x1 As Integer, ByVal y1 As Integer, _
                                  ByVal x2 As Integer, ByVal y2 As Integer, _
                                  ByVal clr As ULong, ByVal alpha As Integer)
    /'
        Gfxlib's LINE statement does not blend. The imported graphics renderer
        needs object transparency, so transparent strokes use a small
        Bresenham rasterizer and route every pixel through backend_PSetAlpha.
    '/

    Dim As Integer dx = Abs(x2 - x1)
    Dim As Integer sx = IIf(x1 < x2, 1, -1)
    Dim As Integer dy = -Abs(y2 - y1)
    Dim As Integer sy = IIf(y1 < y2, 1, -1)
    Dim As Integer err_value = dx + dy
    Dim As Integer e2
    Dim As Integer cx = x1
    Dim As Integer cy = y1

    Do
        backend_PSetAlpha(cx, cy, clr, alpha)

        If cx = x2 And cy = y2 Then
            Exit Do
        End If

        e2 = err_value * 2

        If e2 >= dy Then
            err_value += dy
            cx += sx
        End If

        If e2 <= dx Then
            err_value += dx
            cy += sy
        End If
    Loop
End Sub

Sub backend_LineEx(ByVal x1 As Integer, ByVal y1 As Integer, _
                   ByVal x2 As Integer, ByVal y2 As Integer, _
                   ByVal clr As ULong, ByVal line_width As Integer, _
                   ByVal alpha As Integer)
    Dim As Integer first_offset
    Dim As Integer last_offset
    Dim As Integer offset

    If alpha < 0 Then alpha = 0
    If alpha > 255 Then alpha = 255

    If line_width <= 0 Or alpha <= 0 Then
        Exit Sub
    End If

    If line_width = 1 And alpha >= 255 Then
        backend_Line(x1, y1, x2, y2, clr)
        Exit Sub
    End If

    /'
        Imported System Platform line widths are literal pixel widths.

        The old radius-based widening drew -radius..radius, so width 2 and
        width 3 both occupied three pixels.  Even widths cannot be perfectly
        centered on a one-pixel raster line, so they are biased down/right by
        one pixel while still drawing exactly the requested width.
    '/
    first_offset = -((line_width - 1) \ 2)
    last_offset = first_offset + line_width - 1

    If Abs(x2 - x1) >= Abs(y2 - y1) Then
        For offset = first_offset To last_offset
            If alpha >= 255 Then
                backend_Line(x1, y1 + offset, x2, y2 + offset, clr)
            Else
                backend_DrawLineAlpha(x1, y1 + offset, x2, y2 + offset, clr, alpha)
            End If
        Next offset
    Else
        For offset = first_offset To last_offset
            If alpha >= 255 Then
                backend_Line(x1 + offset, y1, x2 + offset, y2, clr)
            Else
                backend_DrawLineAlpha(x1 + offset, y1, x2 + offset, y2, clr, alpha)
            End If
        Next offset
    End If
End Sub

Sub backend_RectEx(ByVal x As Integer, ByVal y As Integer, _
                   ByVal w As Integer, ByVal h As Integer, _
                   ByVal clr As ULong, ByVal filled As Integer, _
                   ByVal line_width As Integer, ByVal alpha As Integer)
    Dim As Integer px
    Dim As Integer py
    Dim As Integer inset

    If w <= 0 Or h <= 0 Then Exit Sub
    If alpha < 0 Then alpha = 0
    If alpha > 255 Then alpha = 255

    If alpha <= 0 Then
        Exit Sub
    End If

    If alpha >= 255 And line_width = 1 Then
        backend_Rect(x, y, w, h, clr, filled)
        Exit Sub
    End If

    If filled <> 0 Then
        If alpha >= 255 Then
            backend_Rect(x, y, w, h, clr, 1)
        Else
            For py = y To y + h - 1
                For px = x To x + w - 1
                    backend_PSetAlpha(px, py, clr, alpha)
                Next px
            Next py
        End If
    Else
        If line_width <= 0 Then
            Exit Sub
        End If

        For inset = 0 To line_width - 1
            backend_LineEx(x + inset, y + inset, x + w - 1 - inset, y + inset, clr, 1, alpha)
            backend_LineEx(x + inset, y + h - 1 - inset, x + w - 1 - inset, y + h - 1 - inset, clr, 1, alpha)
            backend_LineEx(x + inset, y + inset, x + inset, y + h - 1 - inset, clr, 1, alpha)
            backend_LineEx(x + w - 1 - inset, y + inset, x + w - 1 - inset, y + h - 1 - inset, clr, 1, alpha)
        Next inset
    End If
End Sub

Sub backend_PSet(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong) : PSet (x, y), MapColor(clr) : End Sub

Sub backend_Circle(ByVal x As Integer, ByVal y As Integer, ByVal r As Integer, ByVal clr As ULong, ByVal filled As Integer)
    If filled Then : Circle (x, y), r, MapColor(clr), , , , F : Else : Circle (x, y), r, MapColor(clr) : End If
End Sub

Sub backend_Curve(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal x3 As Integer, ByVal y3 As Integer, ByVal clr As ULong)
    Dim As Double t
    Dim As Double pixelX
    Dim As Double pixelY
    Dim As Integer oldX
    Dim As Integer oldY
    Dim As ULong mappedColor = MapColor(clr)

    For t = 0.0 To 1.0 Step BACKEND_CURVE_STEP
        pixelX = (1.0 - t) ^ 2 * x1 + 2.0 * (1.0 - t) * t * x2 + t ^ 2 * x3
        pixelY = (1.0 - t) ^ 2 * y1 + 2.0 * (1.0 - t) * t * y2 + t ^ 2 * y3

        If t > 0.0 Then
            Line (oldX, oldY)-(CInt(pixelX), CInt(pixelY)), mappedColor
        End If

        oldX = CInt(pixelX)
        oldY = CInt(pixelY)
    Next
End Sub

' -------------------------------------------------------------------------
' Text (Alpha Blended)
' -------------------------------------------------------------------------

Private Function backend_FontGlyph(ByVal font_id As Integer, _
                                   ByVal char_code As Integer) As UByte Ptr
    If char_code < 32 Or char_code > 126 Then
        Return 0
    End If

    Select Case font_id
    Case BACKEND_FONT_ARIAL_10_REGULAR
        Return font_arial_10_regular_chars(char_code)
    Case BACKEND_FONT_ARIAL_12_BOLD
        Return font_arial_12_bold_chars(char_code)
    Case Else
        Return font_chars(char_code)
    End Select
End Function

#Ifdef __FB_GFXLIB3__
Private Function backend_DrawTextGfx3( _
    ByVal x As Integer, _
    ByVal y As Integer, _
    ByVal clr As ULong, _
    ByVal text As String, _
    ByVal font_id As Integer, _
    ByVal scale_x As Integer, _
    ByVal scale_y As Integer, _
    ByVal text_alpha As Integer _
) As Integer
    Dim As Integer screen_w
    Dim As Integer screen_h
    Dim As Integer screen_d
    Dim As Integer character_code
    Dim As Integer glyph_width
    Dim As Integer glyph_height
    Dim As Integer glyph_alpha
    Dim As Integer point_count
    Dim As Integer current_x
    Dim As ULongInt point_capacity
    Dim As ULongInt glyph_capacity
    Dim As UByte Ptr glyph
    Dim points() As fb.Gfx3Point

    If scale_x < 1 Or scale_y < 1 Or text_alpha <= 0 Then
        Return -1
    End If
    If text_alpha > 255 Then text_alpha = 255

    ScreenInfo screen_w, screen_h, screen_d
    If screen_d <> 32 Then Return 0

    /'
        Size the packet before allocation. Gfx3DrawPoints copies it into the
        renderer queue before returning, so this temporary array never escapes
        the call and can be released by FreeBASIC at function exit.
    '/
    For index As Integer = 0 To Len(text) - 1
        character_code = text[index]
        glyph = backend_FontGlyph(font_id, character_code)

        If glyph <> 0 Then
            glyph_capacity = CULngInt(glyph[0]) * CULngInt(glyph[1]) * _
                             CULngInt(scale_x) * CULngInt(scale_y)
            If glyph_capacity > BACKEND_GFX3_TEXT_POINT_LIMIT - point_capacity Then
                Return 0
            End If
            point_capacity += glyph_capacity
        End If
    Next index

    If point_capacity = 0 Then Return -1
    ReDim points(0 To CInt(point_capacity) - 1)

    current_x = x
    For index As Integer = 0 To Len(text) - 1
        character_code = text[index]
        glyph = backend_FontGlyph(font_id, character_code)

        If glyph <> 0 Then
            glyph_width = glyph[0]
            glyph_height = glyph[1]

            For pixel_y As Integer = 0 To glyph_height - 1
                For pixel_x As Integer = 0 To glyph_width - 1
                    glyph_alpha = (CInt(glyph[2 + pixel_y * glyph_width + pixel_x]) * _
                                   text_alpha) \ 255

                    If glyph_alpha > 0 Then
                        For scaled_y As Integer = 0 To scale_y - 1
                            For scaled_x As Integer = 0 To scale_x - 1
                                points(point_count).x = current_x + _
                                    (pixel_x * scale_x) + scaled_x
                                points(point_count).y = y + _
                                    (pixel_y * scale_y) + scaled_y
                                points(point_count).color = clr
                                points(point_count).alpha = _
                                    backend_Gfx3Alpha(glyph_alpha)
                                point_count += 1
                            Next scaled_x
                        Next scaled_y
                    End If
                Next pixel_x
            Next pixel_y

            current_x += glyph_width * scale_x
        End If
    Next index

    If point_count = 0 Then Return -1
    If fb.Gfx3DrawPoints(0, @points(0), point_count) <> 0 Then Return 0
    Return -1
End Function
#EndIf

Private Function backend_AlignedX(ByVal x As Integer, ByVal w As Integer, _
                                  ByVal text_w As Integer, _
                                  ByVal horizontal_align As Integer) As Integer
    Select Case horizontal_align
    Case BACKEND_ALIGN_CENTER
        Return x + ((w - text_w) \ 2)
    Case BACKEND_ALIGN_RIGHT
        Return x + w - text_w
    Case Else
        Return x
    End Select
End Function

Private Function backend_AlignedY(ByVal y As Integer, ByVal h As Integer, _
                                  ByVal text_h As Integer, _
                                  ByVal vertical_align As Integer) As Integer
    Select Case vertical_align
    Case BACKEND_ALIGN_MIDDLE
        Return y + ((h - text_h) \ 2)
    Case BACKEND_ALIGN_BOTTOM
        Return y + h - text_h
    Case Else
        Return y
    End Select
End Function

Private Sub DrawCharFont(ByVal x As Integer, ByVal y As Integer, _
                         ByVal charCode As Integer, ByVal clr As ULong, _
                         ByVal font_id As Integer, ByVal text_alpha As Integer)
    If charCode < 32 Or charCode > 126 Then Exit Sub
    Dim As UByte Ptr p = backend_FontGlyph(font_id, charCode) : If p = 0 Then Exit Sub

    Dim As Integer w = p[0]
    Dim As Integer h = p[1]
    Dim As ULong r = (clr Shr 16) And &HFF
    Dim As ULong g = (clr Shr 8) And &HFF
    Dim As ULong b = clr And &HFF

    Dim As Integer scrW, scrH, scrD
    ScreenInfo scrW, scrH, scrD

    If text_alpha <= 0 Then Exit Sub
    If text_alpha > 255 Then text_alpha = 255

    For py As Integer = 0 To h - 1
        For px As Integer = 0 To w - 1
            Dim As Integer alpha = (CInt(p[2 + py * w + px]) * text_alpha) \ 255

            If alpha > 0 Then
                If scrD < 16 Then
                    If alpha > 128 Then PSet (x + px, y + py), MapColor(clr)
                Elseif alpha = 255 Then
                    PSet (x + px, y + py), MapColor(clr)
                Else
                    Dim As ULong bg = Point(x + px, y + py)
                    Dim As ULong br = (bg Shr 16) And &HFF
                    Dim As ULong bg_g = (bg Shr 8) And &HFF
                    Dim As ULong bb = bg And &HFF

                    Dim As ULong resR = (r * alpha + br * (255 - alpha)) \ 255
                    Dim As ULong resG = (g * alpha + bg_g * (255 - alpha)) \ 255
                    Dim As ULong resB = (b * alpha + bb * (255 - alpha)) \ 255

                    PSet (x + px, y + py), RGB(resR, resG, resB)
                End If
            End If
        Next
    Next
End Sub

Private Sub DrawCharScaledFont(ByVal x As Integer, ByVal y As Integer, _
                               ByVal charCode As Integer, ByVal clr As ULong, _
                               ByVal font_id As Integer, _
                               ByVal scale_x As Integer, ByVal scale_y As Integer, _
                               ByVal text_alpha As Integer)
    Dim As UByte Ptr p
    Dim As Integer w
    Dim As Integer h
    Dim As Integer alpha
    Dim As Integer px
    Dim As Integer py
    Dim As Integer sx
    Dim As Integer sy

    If charCode < 32 Or charCode > 126 Then Exit Sub

    If scale_x < 1 Then scale_x = 1
    If scale_y < 1 Then scale_y = 1
    If text_alpha <= 0 Then Exit Sub
    If text_alpha > 255 Then text_alpha = 255

    p = backend_FontGlyph(font_id, charCode)
    If p = 0 Then Exit Sub

    w = p[0]
    h = p[1]

    For py = 0 To h - 1
        For px = 0 To w - 1
            alpha = (CInt(p[2 + py * w + px]) * text_alpha) \ 255

            If alpha > 0 Then
                For sy = 0 To scale_y - 1
                    For sx = 0 To scale_x - 1
                        backend_PSetAlpha(x + (px * scale_x) + sx, _
                                          y + (py * scale_y) + sy, _
                                          clr, alpha)
                    Next sx
                Next sy
            End If
        Next px
    Next py
End Sub

Sub backend_PrintFont(ByVal x As Integer, ByVal y As Integer, _
                      ByVal clr As ULong, ByVal text As String, _
                      ByVal font_id As Integer)
    backend_PrintFontAlpha x, y, clr, text, font_id, 255
End Sub

Sub backend_PrintFontAlpha(ByVal x As Integer, ByVal y As Integer, _
                           ByVal clr As ULong, ByVal text As String, _
                           ByVal font_id As Integer, ByVal alpha As Integer)
#Ifdef __FB_GFXLIB3__
    If backend_DrawTextGfx3(x, y, clr, text, font_id, 1, 1, alpha) Then
        Exit Sub
    End If
#EndIf

    Dim As Integer curX = x : For i As Integer = 0 To Len(text) - 1
        Dim As Integer charCode = text[i]
        DrawCharFont(curX, y, charCode, clr, font_id, alpha)
        If charCode >= 32 And charCode <= 126 Then
            If backend_FontGlyph(font_id, charCode) <> 0 Then
                curX += backend_FontGlyph(font_id, charCode)[0]
            End If
        End If
    Next
End Sub

Sub backend_Print(ByVal x As Integer, ByVal y As Integer, ByVal clr As ULong, ByVal text As String)
    backend_PrintFont x, y, clr, text, BACKEND_FONT_DEFAULT
End Sub

Sub backend_PrintScaledFont(ByVal x As Integer, ByVal y As Integer, _
                            ByVal clr As ULong, ByVal text As String, _
                            ByVal font_id As Integer, _
                            ByVal scale_x As Integer, ByVal scale_y As Integer)
    backend_PrintScaledFontAlpha x, y, clr, text, font_id, scale_x, scale_y, 255
End Sub

Sub backend_PrintScaledFontAlpha(ByVal x As Integer, ByVal y As Integer, _
                                 ByVal clr As ULong, ByVal text As String, _
                                 ByVal font_id As Integer, _
                                 ByVal scale_x As Integer, ByVal scale_y As Integer, _
                                 ByVal alpha As Integer)
    Dim As Integer cur_x = x
    Dim As Integer i
    Dim As Integer char_code
    Dim As UByte Ptr glyph

    If scale_x < 1 Then scale_x = 1
    If scale_y < 1 Then scale_y = 1

#Ifdef __FB_GFXLIB3__
    If backend_DrawTextGfx3(x, y, clr, text, font_id, scale_x, scale_y, alpha) Then
        Exit Sub
    End If
#EndIf

    For i = 0 To Len(text) - 1
        char_code = text[i]
        DrawCharScaledFont(cur_x, y, char_code, clr, font_id, scale_x, scale_y, alpha)

        If char_code >= 32 And char_code <= 126 Then
            glyph = backend_FontGlyph(font_id, char_code)
            If glyph <> 0 Then
                cur_x += glyph[0] * scale_x
            End If
        End If
    Next i
End Sub

Sub backend_PrintScaled(ByVal x As Integer, ByVal y As Integer, _
                        ByVal clr As ULong, ByVal text As String, _
                        ByVal scale_x As Integer, ByVal scale_y As Integer)
    backend_PrintScaledFont x, y, clr, text, BACKEND_FONT_DEFAULT, scale_x, scale_y
End Sub

Sub backend_PrintAlignedScaled(ByVal x As Integer, ByVal y As Integer, _
                               ByVal w As Integer, ByVal h As Integer, _
                               ByVal clr As ULong, ByVal text As String, _
                               ByVal font_id As Integer, _
                               ByVal horizontal_align As Integer, _
                               ByVal vertical_align As Integer, _
                               ByVal scale_x As Integer, _
                               ByVal scale_y As Integer)
    backend_PrintAlignedScaledAlpha x, y, w, h, clr, text, font_id, _
                                    horizontal_align, vertical_align, _
                                    scale_x, scale_y, 255
End Sub

Sub backend_PrintAlignedScaledAlpha(ByVal x As Integer, ByVal y As Integer, _
                                    ByVal w As Integer, ByVal h As Integer, _
                                    ByVal clr As ULong, ByVal text As String, _
                                    ByVal font_id As Integer, _
                                    ByVal horizontal_align As Integer, _
                                    ByVal vertical_align As Integer, _
                                    ByVal scale_x As Integer, _
                                    ByVal scale_y As Integer, _
                                    ByVal alpha As Integer)
    Dim text_w As Integer
    Dim text_h As Integer
    Dim draw_x As Integer
    Dim draw_y As Integer

    If scale_x < 1 Then scale_x = 1
    If scale_y < 1 Then scale_y = 1
    If alpha <= 0 Then Exit Sub
    If alpha > 255 Then alpha = 255

    text_w = backend_GetTextWidthScaledFont(text, font_id, scale_x)
    text_h = backend_GetTextHeightScaledFont(font_id, scale_y)
    draw_x = backend_AlignedX(x, w, text_w, horizontal_align)
    draw_y = backend_AlignedY(y, h, text_h, vertical_align)

    backend_PrintScaledFontAlpha draw_x, draw_y, clr, text, font_id, _
                                 scale_x, scale_y, alpha
End Sub

Sub backend_PrintAligned(ByVal x As Integer, ByVal y As Integer, _
                         ByVal w As Integer, ByVal h As Integer, _
                         ByVal clr As ULong, ByVal text As String, _
                         ByVal font_id As Integer, _
                         ByVal horizontal_align As Integer, _
                         ByVal vertical_align As Integer)
    backend_PrintAlignedAlpha x, y, w, h, clr, text, font_id, _
                              horizontal_align, vertical_align, 255
End Sub

Sub backend_PrintAlignedAlpha(ByVal x As Integer, ByVal y As Integer, _
                              ByVal w As Integer, ByVal h As Integer, _
                              ByVal clr As ULong, ByVal text As String, _
                              ByVal font_id As Integer, _
                              ByVal horizontal_align As Integer, _
                              ByVal vertical_align As Integer, _
                              ByVal alpha As Integer)
    backend_PrintAlignedScaledAlpha x, y, w, h, clr, text, font_id, _
                                    horizontal_align, vertical_align, _
                                    1, 1, alpha
End Sub

Function backend_GetTextWidth(ByVal text As String) As Integer
    Return backend_GetTextWidthFont(text, BACKEND_FONT_DEFAULT)
End Function

Function backend_GetTextWidthFont(ByVal text As String, ByVal font_id As Integer) As Integer
    Dim As Integer w = 0
    Dim As UByte Ptr glyph

    For i As Integer = 0 To Len(text) - 1
        Dim As Integer charCode = text[i]
        glyph = backend_FontGlyph(font_id, charCode)

        If glyph <> 0 Then
            w += glyph[0]
        End If
    Next

    Return w
End Function

Function backend_GetTextWidthScaled(ByVal text As String, ByVal scale_x As Integer) As Integer
    Return backend_GetTextWidthScaledFont(text, BACKEND_FONT_DEFAULT, scale_x)
End Function

Function backend_GetTextWidthScaledFont(ByVal text As String, _
                                        ByVal font_id As Integer, _
                                        ByVal scale_x As Integer) As Integer
    If scale_x < 1 Then scale_x = 1
    Return backend_GetTextWidthFont(text, font_id) * scale_x
End Function

Function backend_GetTextHeight() As Integer : Return 14 : End Function

Function backend_GetTextHeightScaled(ByVal scale_y As Integer) As Integer
    Return backend_GetTextHeightScaledFont(BACKEND_FONT_DEFAULT, scale_y)
End Function

Function backend_GetTextHeightFont(ByVal font_id As Integer) As Integer
    Dim glyph As UByte Ptr

    glyph = backend_FontGlyph(font_id, Asc("M"))

    If glyph <> 0 Then
        Return glyph[1]
    End If

    Return 14
End Function

Function backend_GetTextHeightScaledFont(ByVal font_id As Integer, _
                                         ByVal scale_y As Integer) As Integer
    If scale_y < 1 Then scale_y = 1
    Return backend_GetTextHeightFont(font_id) * scale_y
End Function

' -------------------------------------------------------------------------
' Clipping
' -------------------------------------------------------------------------

Sub backend_SetClip(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer)
    Dim screen_w As Integer
    Dim screen_h As Integer
    Dim x1 As Integer
    Dim y1 As Integer
    Dim x2 As Integer
    Dim y2 As Integer

    Dim stackIndex As Integer

    /'
        Gfxlib clipping is global state. Treat SetClip and ResetClip as a
        balanced push and pop so the GUI manager can install a parent client
        clip while a textbox, list, or graphic shape adds a narrower local
        clip for its own renderer.
    '/

    If backend_ClipDepth >= BACKEND_CLIP_STACK_CAPACITY Then
        backend_ClipOverflowDepth += 1
        Exit Sub
    End If

    If w <= 0 Or h <= 0 Then
        w = 1
        h = 1
    End If

    ScreenInfo screen_w, screen_h

    If screen_w <= 0 Or screen_h <= 0 Then
        screen_w = 1
        screen_h = 1
    End If

    x1 = x
    y1 = y
    x2 = x + w - 1
    y2 = y + h - 1

    If x1 < 0 Then x1 = 0
    If y1 < 0 Then y1 = 0
    If x2 >= screen_w Then x2 = screen_w - 1
    If y2 >= screen_h Then y2 = screen_h - 1

    If backend_ClipDepth > 0 Then
        stackIndex = backend_ClipDepth - 1

        If x1 < backend_ClipX1(stackIndex) Then _
            x1 = backend_ClipX1(stackIndex)
        If y1 < backend_ClipY1(stackIndex) Then _
            y1 = backend_ClipY1(stackIndex)
        If x2 > backend_ClipX2(stackIndex) Then _
            x2 = backend_ClipX2(stackIndex)
        If y2 > backend_ClipY2(stackIndex) Then _
            y2 = backend_ClipY2(stackIndex)
    End If

    If x2 < x1 Or y2 < y1 Then
        x1 = 0
        y1 = 0
        x2 = 0
        y2 = 0
    End If

    stackIndex = backend_ClipDepth
    backend_ClipX1(stackIndex) = x1
    backend_ClipY1(stackIndex) = y1
    backend_ClipX2(stackIndex) = x2
    backend_ClipY2(stackIndex) = y2
    backend_ClipDepth += 1
    View Screen (x1, y1)-(x2, y2)
End Sub

Sub backend_ResetClip()
    Dim stackIndex As Integer

    If backend_ClipOverflowDepth > 0 Then
        backend_ClipOverflowDepth -= 1
        Exit Sub
    End If

    If backend_ClipDepth > 0 Then backend_ClipDepth -= 1

    If backend_ClipDepth = 0 Then
        View Screen
    Else
        stackIndex = backend_ClipDepth - 1
        View Screen _
            (backend_ClipX1(stackIndex), backend_ClipY1(stackIndex))- _
            (backend_ClipX2(stackIndex), backend_ClipY2(stackIndex))
    End If
End Sub

Private Sub backend_WriteBmpByte(ByVal file_number As Integer, _
                                 ByVal value As Integer)
    Dim byte_value As UByte = value And &HFF

    Put #file_number, , byte_value
End Sub

Private Sub backend_WriteBmpU16(ByVal file_number As Integer, _
                                ByVal value As UInteger)
    backend_WriteBmpByte file_number, value And &HFF
    backend_WriteBmpByte file_number, (value Shr 8) And &HFF
End Sub

Private Sub backend_WriteBmpU32(ByVal file_number As Integer, _
                                ByVal value As UInteger)
    backend_WriteBmpByte file_number, value And &HFF
    backend_WriteBmpByte file_number, (value Shr 8) And &HFF
    backend_WriteBmpByte file_number, (value Shr 16) And &HFF
    backend_WriteBmpByte file_number, (value Shr 24) And &HFF
End Sub

Sub backend_SaveSnapshot(ByVal filename As String)
    Dim screen_w As Integer
    Dim screen_h As Integer
    Dim screen_depth As Integer
    Dim screen_bpp As Integer
    Dim screen_pitch As Integer
    Dim bytes_per_pixel As Integer
    Dim file_number As Integer
    Dim row_stride As Integer
    Dim pixel_data_size As UInteger
    Dim file_size As UInteger
    Dim x As Integer
    Dim y As Integer
    Dim pad_index As Integer
    Dim screen_buffer As Any Ptr
    Dim row_ptr As UByte Ptr
    Dim pixel_ptr As UByte Ptr
    Dim blue_value As Integer
    Dim green_value As Integer
    Dim red_value As Integer

    /'
        Snapshot file format

        Test and extraction tools need deterministic BMP files from headless
        renders. The writer below emits a plain 24-bit Windows BMP:

            14 bytes : BMP file header
            40 bytes : BITMAPINFOHEADER
            rows     : bottom-up BGR pixels, padded to a 4-byte boundary

        gfxlib screens in this backend are created as 32-bit RGB surfaces.
        Reading the framebuffer directly avoids small-preview quirks in BSave.
    '/

    If Len(filename) = 0 Then Exit Sub

    ScreenInfo screen_w, screen_h, screen_depth, screen_bpp, screen_pitch

    If screen_w <= 0 Or screen_h <= 0 Then Exit Sub

    screen_buffer = ScreenPtr()

    If screen_buffer = 0 Then Exit Sub

    bytes_per_pixel = screen_bpp

    If bytes_per_pixel > 8 Then
        bytes_per_pixel = bytes_per_pixel \ 8
    End If

    If bytes_per_pixel <= 0 Then
        bytes_per_pixel = screen_depth \ 8
    End If

    If bytes_per_pixel < 3 Then Exit Sub

    If screen_pitch <= 0 Then
        screen_pitch = screen_w * bytes_per_pixel
    End If

    row_stride = ((screen_w * 3 + 3) \ 4) * 4
    pixel_data_size = row_stride * screen_h
    file_size = 54 + pixel_data_size

    If Dir(filename) <> "" Then
        Kill filename
    End If

    file_number = FreeFile

    If Open(filename For Binary Access Write As #file_number) <> 0 Then
        Exit Sub
    End If

    backend_WriteBmpByte file_number, Asc("B")
    backend_WriteBmpByte file_number, Asc("M")
    backend_WriteBmpU32 file_number, file_size
    backend_WriteBmpU32 file_number, 0
    backend_WriteBmpU32 file_number, 54

    backend_WriteBmpU32 file_number, 40
    backend_WriteBmpU32 file_number, screen_w
    backend_WriteBmpU32 file_number, screen_h
    backend_WriteBmpU16 file_number, 1
    backend_WriteBmpU16 file_number, 24
    backend_WriteBmpU32 file_number, 0
    backend_WriteBmpU32 file_number, pixel_data_size
    backend_WriteBmpU32 file_number, 2835
    backend_WriteBmpU32 file_number, 2835
    backend_WriteBmpU32 file_number, 0
    backend_WriteBmpU32 file_number, 0

    For y = screen_h - 1 To 0 Step -1
        row_ptr = Cast(UByte Ptr, screen_buffer) + (y * screen_pitch)

        For x = 0 To screen_w - 1
            pixel_ptr = row_ptr + (x * bytes_per_pixel)
            blue_value = pixel_ptr[0]
            green_value = pixel_ptr[1]
            red_value = pixel_ptr[2]

            backend_WriteBmpByte file_number, blue_value
            backend_WriteBmpByte file_number, green_value
            backend_WriteBmpByte file_number, red_value
        Next x

        For pad_index = (screen_w * 3) + 1 To row_stride
            backend_WriteBmpByte file_number, 0
        Next pad_index
    Next y

    Close #file_number
End Sub

' end of backend_gfxlib.bas

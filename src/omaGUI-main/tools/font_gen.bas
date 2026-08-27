/'
    Project: omaGUI Font Tools
    --------------------------

    File: font_gen.bas

    Purpose:

        Generate omaGUI bitmap font data from a TrueType font.

    Responsibilities:

        - load one TrueType font through SDL_ttf
        - rasterize printable ASCII glyphs into 8-bit alpha data
        - write a FreeBASIC include file containing the glyph bitmaps
        - optionally write a BMP atlas for visual inspection

    This file intentionally does NOT contain:

        - runtime text drawing logic
        - font selection policy for the renderer
        - Wonderware/System Platform graphics parsing
'/

#lang "fb"

#include "SDL2/SDL.bi"
#include "SDL2/SDL_ttf.bi"

Const FIRST_GLYPH As Integer = 32
Const LAST_GLYPH As Integer = 126
Const DEFAULT_POINT_SIZE As Integer = 12
Const ATLAS_COLUMNS As Integer = 16
' SDL2 assigns value one to ordinary source-alpha blending.
Const FONTGEN_BLENDMODE_BLEND As Integer = &h00000001

' -------------------------------------------------------------------------
' Output helpers
' -------------------------------------------------------------------------

Sub PrintUsage()
    Print "Usage:"
    Print "  font_gen.exe [font-path] [point-size] [symbol-prefix] [data-output.bi] [atlas-output.bmp]"
    Print ""
    Print "Example:"
    Print "  font_gen.exe C:\Windows\Fonts\arial.ttf 10 font_arial_10_regular assets\fonts\font_arial_10_regular.bi assets\fonts\font_arial_10_regular.bmp"
End Sub

Function DefaultFontPath() As String
#ifdef __FB_WIN32__
    Return "C:\Windows\Fonts\arial.ttf"
#else
    Return "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
#endif
End Function

Function SafePointSize(ByRef text As String) As Integer
    Dim value As Integer

    value = ValInt(text)

    If value <= 0 Then
        value = DEFAULT_POINT_SIZE
    End If

    Return value
End Function

Sub EmitLine(ByVal file_number As Integer, _
             ByVal use_file As Integer, _
             ByRef text As String)
    If use_file <> 0 Then
        Print #file_number, text
    Else
        Print text
    End If
End Sub

' -------------------------------------------------------------------------
' Font data generation
' -------------------------------------------------------------------------

Sub EmitFileHeader(ByVal file_number As Integer, _
                   ByVal use_file As Integer, _
                   ByRef symbol_prefix As String, _
                   ByRef font_path As String, _
                   ByVal point_size As Integer)
    EmitLine file_number, use_file, "/'"
    EmitLine file_number, use_file, "    Project: omaGUI Generated Bitmap Font"
    EmitLine file_number, use_file, "    ------------------------------------"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    File: " & symbol_prefix & ".bi"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    Purpose:"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "        Store one generated bitmap font for the omaGUI renderer."
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    Source font:"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "        " & font_path
    EmitLine file_number, use_file, "        point size " & Str(point_size)
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "    This file intentionally does NOT contain:"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "        - runtime font selection"
    EmitLine file_number, use_file, "        - text layout logic"
    EmitLine file_number, use_file, "        - the source TrueType font"
    EmitLine file_number, use_file, "'/"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "#ifndef __" & UCase(symbol_prefix) & "_BI__"
    EmitLine file_number, use_file, "#define __" & UCase(symbol_prefix) & "_BI__"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "' Format: Width, Height, AlphaData..."
    EmitLine file_number, use_file, "Dim Shared As UByte Ptr " & symbol_prefix & "_chars(32 To 126)"
    EmitLine file_number, use_file, ""
End Sub

Sub EmitGlyphData(ByVal file_number As Integer, _
                  ByVal use_file As Integer, _
                  ByRef symbol_prefix As String, _
                  ByVal character_code As Integer, _
                  ByVal surface As SDL_Surface Ptr)
    Dim pixels As UByte Ptr
    Dim pixel_value As ULong
    Dim alpha As UByte
    Dim line_text As String
    Dim pixel_text As String
    Dim suffix_text As String
    Dim output_position As Integer

    If surface = 0 OrElse surface->pixels = 0 Then Exit Sub
    If surface->w <= 0 OrElse surface->h <= 0 Then Exit Sub
    If surface->pitch < surface->w * SizeOf(ULong) Then Exit Sub

    EmitLine file_number, use_file, "' Font data for character " & _
             Str(character_code) & " ('" & Chr(character_code) & "')"
    EmitLine file_number, use_file, "Static Shared As UByte " & symbol_prefix & _
             "_char_" & Trim(Str(character_code)) & "_data(...) = { _"
    EmitLine file_number, use_file, "  " & Str(surface->w) & ", " & _
             Str(surface->h) & ", _"

    pixels = surface->pixels

    For y As Integer = 0 To surface->h - 1
        ' Three alpha digits, one comma, and the line suffix bound each pixel.
        line_text = Space(2 + (surface->w * 4) + 4)
        Mid(line_text, 1, 2) = "  "
        output_position = 3

        For x As Integer = 0 To surface->w - 1
            pixel_value = *Cast( _
                ULong Ptr, _
                pixels + (y * surface->pitch) + (x * SizeOf(ULong)) _
            )
            alpha = (pixel_value Shr 24) And &HFF
            If x < surface->w - 1 Or y < surface->h - 1 Then
                pixel_text = Trim(Str(alpha)) & ","
            Else
                pixel_text = Trim(Str(alpha))
            End If

            Mid(line_text, output_position, Len(pixel_text)) = pixel_text
            output_position += Len(pixel_text)
        Next x

        If y < surface->h - 1 Then
            suffix_text = " _"
        Else
            suffix_text = " , _"
        End If

        Mid(line_text, output_position, Len(suffix_text)) = suffix_text
        line_text = Left(line_text, output_position + Len(suffix_text) - 1)

        EmitLine file_number, use_file, line_text
    Next y

    EmitLine file_number, use_file, "0 }"
    EmitLine file_number, use_file, ""
End Sub

Sub EmitInitBlock(ByVal file_number As Integer, _
                  ByVal use_file As Integer, _
                  ByRef symbol_prefix As String)
    EmitLine file_number, use_file, "Sub " & symbol_prefix & "_init_pointers()"
    EmitLine file_number, use_file, "    /'"
    EmitLine file_number, use_file, "        The drawing backend indexes printable ASCII characters"
    EmitLine file_number, use_file, "        directly by character code. Each pointer references one"
    EmitLine file_number, use_file, "        generated width, height, alpha-data block."
    EmitLine file_number, use_file, "    '/"

    For i As Integer = FIRST_GLYPH To LAST_GLYPH
        EmitLine file_number, use_file, "    " & symbol_prefix & "_chars(" & _
                 Trim(Str(i)) & ") = @" & symbol_prefix & "_char_" & _
                 Trim(Str(i)) & "_data(0)"
    Next i

    EmitLine file_number, use_file, "End Sub"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "#endif"
    EmitLine file_number, use_file, ""
    EmitLine file_number, use_file, "/' end of " & symbol_prefix & ".bi '/"
End Sub

Function SaveAtlas(ByVal font As TTF_Font Ptr, _
                   ByRef atlas_path As String, _
                   ByVal max_width As Integer, _
                   ByVal max_height As Integer) As Integer
    Dim rows As Integer
    Dim cell_width As Integer
    Dim cell_height As Integer
    Dim atlas_width As Integer
    Dim atlas_height As Integer
    Dim atlas As SDL_Surface Ptr
    Dim glyph As SDL_Surface Ptr
    Dim dest As SDL_Rect
    Dim white As SDL_Color
    Dim black As ULong

    If Len(atlas_path) = 0 Then
        Return -1
    End If

    rows = ((LAST_GLYPH - FIRST_GLYPH + 1) + ATLAS_COLUMNS - 1) \ ATLAS_COLUMNS
    cell_width = max_width + 4
    cell_height = max_height + 4
    atlas_width = ATLAS_COLUMNS * cell_width
    atlas_height = rows * cell_height

    If cell_width < 4 Or cell_height < 4 Then
        Print "ERROR: Invalid atlas cell dimensions."
        Return 0
    End If

    atlas = SDL_CreateRGBSurface(0, atlas_width, atlas_height, 32, _
                                 &H00FF0000, &H0000FF00, &H000000FF, _
                                 &HFF000000)
    If atlas = 0 Then
        Print "ERROR: Could not create atlas surface."
        Return 0
    End If

    black = SDL_MapRGB(atlas->format, 0, 0, 0)
    SDL_FillRect(atlas, 0, black)

    white.r = 255
    white.g = 255
    white.b = 255
    white.a = 255

    For i As Integer = FIRST_GLYPH To LAST_GLYPH
        glyph = TTF_RenderGlyph_Blended(font, i, white)

        If glyph <> 0 Then
            SDL_SetSurfaceBlendMode(glyph, FONTGEN_BLENDMODE_BLEND)
            dest.x = ((i - FIRST_GLYPH) Mod ATLAS_COLUMNS) * cell_width + 2
            dest.y = ((i - FIRST_GLYPH) \ ATLAS_COLUMNS) * cell_height + 2
            dest.w = glyph->w
            dest.h = glyph->h
            SDL_BlitSurface(glyph, 0, atlas, @dest)
            SDL_FreeSurface(glyph)
        End If
    Next i

    If SDL_SaveBMP(atlas, atlas_path) <> 0 Then
        Print "ERROR: Could not save atlas " & atlas_path
        SDL_FreeSurface(atlas)
        Return 0
    End If

    SDL_FreeSurface(atlas)
    Return -1
End Function

Function GenerateFontData(ByRef font_path As String, _
                          ByVal point_size As Integer, _
                          ByRef symbol_prefix As String, _
                          ByRef data_output_path As String, _
                          ByRef atlas_output_path As String) As Integer
    Dim file_number As Integer
    Dim use_file As Integer
    Dim font As TTF_Font Ptr
    Dim surface As SDL_Surface Ptr
    Dim white As SDL_Color
    Dim max_width As Integer = 0
    Dim max_height As Integer = 0

    If TTF_Init() = -1 Then
        Print "ERROR: Could not initialize SDL_ttf."
        Return 0
    End If

    font = TTF_OpenFont(font_path, point_size)
    If font = 0 Then
        Print "ERROR: Could not load font " & font_path
        TTF_Quit()
        Return 0
    End If

    use_file = 0
    file_number = 0

    If Len(data_output_path) > 0 AndAlso data_output_path <> "-" Then
        file_number = FreeFile

        If Open(data_output_path For Output As #file_number) <> 0 Then
            Print "ERROR: Could not open output file " & data_output_path
            TTF_CloseFont(font)
            TTF_Quit()
            Return 0
        End If

        use_file = -1
    End If

    white.r = 255
    white.g = 255
    white.b = 255
    white.a = 255

    EmitFileHeader file_number, use_file, symbol_prefix, font_path, point_size

    For i As Integer = FIRST_GLYPH To LAST_GLYPH
        surface = TTF_RenderGlyph_Blended(font, i, white)

        If surface <> 0 Then
            If surface->w > max_width Then max_width = surface->w
            If surface->h > max_height Then max_height = surface->h
            EmitGlyphData file_number, use_file, symbol_prefix, i, surface
            SDL_FreeSurface(surface)
        Else
            Print "WARNING: Missing glyph " & Str(i)
        End If
    Next i

    EmitInitBlock file_number, use_file, symbol_prefix

    If use_file <> 0 Then
        Close #file_number
    End If

    If SaveAtlas(font, atlas_output_path, max_width, max_height) = 0 Then
        TTF_CloseFont(font)
        TTF_Quit()
        Return 0
    End If

    TTF_CloseFont(font)
    TTF_Quit()

    Return -1
End Function

' -------------------------------------------------------------------------
' Program entry
' -------------------------------------------------------------------------

Dim font_path As String = Command(1)
Dim point_size As Integer = SafePointSize(Command(2))
Dim symbol_prefix As String = Command(3)
Dim data_output_path As String = Command(4)
Dim atlas_output_path As String = Command(5)

If LCase(font_path) = "--help" Or font_path = "/?" Then
    PrintUsage
    End 0
End If

If Len(font_path) = 0 Then
    font_path = DefaultFontPath()
End If

If Len(symbol_prefix) = 0 Then
    symbol_prefix = "font"
End If

If GenerateFontData(font_path, point_size, symbol_prefix, _
                    data_output_path, atlas_output_path) = 0 Then
    End 1
End If

End 0

/' end of font_gen.bas '/

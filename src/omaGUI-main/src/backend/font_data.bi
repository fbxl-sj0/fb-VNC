/'
    Project: omaGUI
    ---------------

    File: font_data.bi

    Purpose:

        Declare the default embedded glyph table used by the text backend.

    Responsibilities:

        - expose printable ASCII glyph pointers
        - expose pointer initialization after glyph data is linked

    This file intentionally does NOT contain:

        - generated glyph bytes
        - text layout or rasterization
'/

#ifndef __FONT_DATA_BI__
#define __FONT_DATA_BI__

#ifndef font_chars_defined
Extern font_chars(32 To 126) As UByte Ptr
#define font_chars_defined
#endif

Declare Sub font_init_pointers()

#endif

/' end of font_data.bi '/

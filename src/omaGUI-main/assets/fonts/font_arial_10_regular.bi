/'
    Project: omaGUI Generated Bitmap Font
    ------------------------------------

    File: font_arial_10_regular.bi

    Purpose:

        Store one generated bitmap font for the omaGUI renderer.

    Source font:

        C:\Windows\Fonts\arial.ttf
        point size 10

    This file intentionally does NOT contain:

        - runtime font selection
        - text layout logic
        - the source TrueType font
'/

#ifndef __FONT_ARIAL_10_REGULAR_BI__
#define __FONT_ARIAL_10_REGULAR_BI__

' Format: Width, Height, AlphaData...
/'
    The font module owns this fixed printable-ASCII lookup table. The renderer
    reads it only after font_arial_10_regular_init_pointers initializes it.
'/
Dim Shared As UByte Ptr font_arial_10_regular_chars(32 To 126)

' Font data for character 32 (' ')
Static Shared As UByte font_arial_10_regular_char_32_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 33 ('!')
Static Shared As UByte font_arial_10_regular_char_33_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  36,244,0, _
  33,241,0, _
  16,223,0, _
  1,200,0, _
  0,163,0, _
  0,0,0, _
  24,232,0, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 34 ('"')
Static Shared As UByte font_arial_10_regular_char_34_data(...) = { _
  4, 12, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  140,116,236,20, _
  132,109,229,13, _
  96,77,173,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0 , _
0 }

' Font data for character 35 ('#')
Static Shared As UByte font_arial_10_regular_char_35_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,27,160,0,187,0, _
  0,81,106,11,172,0, _
  228,255,255,255,255,112, _
  0,183,4,120,65,0, _
  228,255,255,255,255,112, _
  48,140,0,186,0,0, _
  101,86,29,155,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 36 ('$')
Static Shared As UByte font_arial_10_regular_char_36_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  14,184,250,220,55,0, _
  105,153,141,82,200,0, _
  60,214,188,17,0,0, _
  0,47,195,228,105,0, _
  0,0,132,18,232,8, _
  124,142,138,50,231,4, _
  17,180,248,228,84,0, _
  0,0,132,4,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 37 ('%')
Static Shared As UByte font_arial_10_regular_char_37_data(...) = { _
  9, 12, _
  0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0, _
  15,206,225,42,0,64,119,0,0, _
  91,129,73,146,1,174,8,0,0, _
  90,128,74,145,95,90,0,0,0, _
  15,207,226,53,174,77,239,177,1, _
  0,0,0,125,61,187,41,162,54, _
  0,0,24,161,0,185,40,162,53, _
  0,0,150,36,0,73,238,177,1, _
  0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 38 ('&')
Static Shared As UByte font_arial_10_regular_char_38_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,58,222,236,82,0,0, _
  0,156,105,77,181,0,0, _
  0,56,207,177,60,0,0, _
  11,178,173,197,7,58,0, _
  116,132,0,148,193,187,0, _
  112,179,14,50,246,151,0, _
  9,165,242,209,77,183,48, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 39 (''')
Static Shared As UByte font_arial_10_regular_char_39_data(...) = { _
  2, 12, _
  0,0, _
  0,0, _
  0,0, _
  144,112, _
  137,105, _
  103,71, _
  0,0, _
  0,0, _
  0,0, _
  0,0, _
  0,0, _
  0,0 , _
0 }

' Font data for character 40 ('(')
Static Shared As UByte font_arial_10_regular_char_40_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,21,149, _
  0,155,41, _
  17,200,0, _
  74,161,0, _
  94,138,0, _
  72,155,0, _
  14,204,0, _
  0,156,46, _
  0,24,154 , _
0 }

' Font data for character 41 (')')
Static Shared As UByte font_arial_10_regular_char_41_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  33,138,0, _
  0,149,48, _
  0,60,158, _
  0,13,222, _
  0,0,232, _
  0,8,218, _
  0,63,153, _
  0,154,46, _
  34,142,0 , _
0 }

' Font data for character 42 ('*')
Static Shared As UByte font_arial_10_regular_char_42_data(...) = { _
  4, 12, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  64,142,112,49, _
  17,191,170,10, _
  26,127,152,8, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0 , _
0 }

' Font data for character 43 ('+')
Static Shared As UByte font_arial_10_regular_char_43_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,128,84,0,0, _
  0,0,128,84,0,0, _
  112,255,255,255,255,72, _
  0,0,128,84,0,0, _
  0,0,128,84,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 44 (',')
Static Shared As UByte font_arial_10_regular_char_44_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  28,228,0, _
  15,161,0, _
  0,0,0 , _
0 }

' Font data for character 45 ('-')
Static Shared As UByte font_arial_10_regular_char_45_data(...) = { _
  4, 12, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  176,255,255,4, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0 , _
0 }

' Font data for character 46 ('.')
Static Shared As UByte font_arial_10_regular_char_46_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  24,232,0, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 47 ('/')
Static Shared As UByte font_arial_10_regular_char_47_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,20,158, _
  0,95,85, _
  0,165,14, _
  5,174,0, _
  67,113,0, _
  143,37,0, _
  180,0,0, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 48 ('0')
Static Shared As UByte font_arial_10_regular_char_48_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,144,243,208,42,0, _
  71,199,18,86,189,0, _
  130,105,0,0,223,5, _
  144,85,0,0,212,16, _
  130,103,0,0,228,4, _
  71,198,20,90,195,0, _
  0,144,241,214,48,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 49 ('1')
Static Shared As UByte font_arial_10_regular_char_49_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,63,179,0,0, _
  0,124,213,184,0,0, _
  0,84,44,184,0,0, _
  0,0,40,184,0,0, _
  0,0,40,184,0,0, _
  0,0,40,184,0,0, _
  0,0,40,184,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 50 ('2')
Static Shared As UByte font_arial_10_regular_char_50_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  6,166,243,223,78,0, _
  101,159,11,56,232,0, _
  0,0,0,14,216,0, _
  0,0,15,187,84,0, _
  0,42,204,79,0,0, _
  30,204,37,0,0,0, _
  150,255,255,255,255,8, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 51 ('3')
Static Shared As UByte font_arial_10_regular_char_51_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  2,155,244,204,33,0, _
  83,179,19,98,171,0, _
  0,0,11,115,141,0, _
  0,0,192,245,77,0, _
  0,0,0,28,230,10, _
  111,157,18,55,233,6, _
  7,168,244,218,73,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 52 ('4')
Static Shared As UByte font_arial_10_regular_char_52_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,28,232,28,0, _
  0,9,181,219,28,0, _
  0,160,60,196,28,0, _
  119,100,0,196,28,0, _
  224,255,255,255,255,20, _
  0,0,0,196,28,0, _
  0,0,0,196,28,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 53 ('5')
Static Shared As UByte font_arial_10_regular_char_53_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,211,255,255,212,0, _
  4,209,0,0,0,0, _
  43,218,229,225,75,0, _
  86,192,16,61,232,6, _
  0,0,0,0,207,29, _
  111,173,19,68,220,2, _
  8,168,243,210,54,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 54 ('6')
Static Shared As UByte font_arial_10_regular_char_54_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,122,233,225,64,0, _
  64,177,19,57,209,0, _
  135,150,226,225,69,0, _
  155,190,19,62,225,1, _
  136,113,0,0,214,19, _
  76,206,27,63,221,1, _
  0,138,237,224,66,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 55 ('7')
Static Shared As UByte font_arial_10_regular_char_55_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  136,255,255,255,255,24, _
  0,0,0,105,144,0, _
  0,0,32,210,8,0, _
  0,0,157,90,0,0, _
  0,13,226,4,0,0, _
  0,79,165,0,0,0, _
  0,123,119,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 56 ('8')
Static Shared As UByte font_arial_10_regular_char_56_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,145,242,212,47,0, _
  57,202,18,89,186,0, _
  47,201,16,83,179,0, _
  3,181,255,250,68,0, _
  116,150,11,47,222,9, _
  126,155,13,43,231,11, _
  15,176,244,225,90,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 57 ('9')
Static Shared As UByte font_arial_10_regular_char_57_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  2,154,242,210,50,0, _
  92,188,19,76,211,0, _
  138,91,0,0,230,16, _
  98,175,15,71,253,26, _
  5,166,244,176,211,9, _
  82,166,15,65,186,0, _
  3,168,245,201,37,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 58 (':')
Static Shared As UByte font_arial_10_regular_char_58_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  24,232,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  24,232,0, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 59 (';')
Static Shared As UByte font_arial_10_regular_char_59_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  28,228,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  28,228,0, _
  15,161,0, _
  0,0,0 , _
0 }

' Font data for character 60 ('<')
Static Shared As UByte font_arial_10_regular_char_60_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,63,171,67, _
  11,103,208,183,80,4, _
  116,233,62,0,0,0, _
  11,104,208,182,79,3, _
  0,0,0,64,172,67, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 61 ('=')
Static Shared As UByte font_arial_10_regular_char_61_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  112,255,255,255,255,72, _
  0,0,0,0,0,0, _
  112,255,255,255,255,72, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 62 ('>')
Static Shared As UByte font_arial_10_regular_char_62_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  104,152,44,0,0,0, _
  10,98,200,191,84,4, _
  0,0,0,93,246,72, _
  10,97,199,192,85,4, _
  104,153,45,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 63 ('?')
Static Shared As UByte font_arial_10_regular_char_63_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  7,168,243,224,88,0, _
  106,166,21,52,236,3, _
  0,0,0,52,201,0, _
  0,0,58,198,26,0, _
  0,0,164,56,0,0, _
  0,0,0,0,0,0, _
  0,0,192,64,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 64 ('@')
Static Shared As UByte font_arial_10_regular_char_64_data(...) = { _
  10, 12, _
  0,0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0,0, _
  0,0,44,166,229,248,218,127,8,0, _
  0,60,220,100,25,7,43,146,189,3, _
  3,201,32,95,231,210,169,85,138,82, _
  66,129,49,219,38,40,246,26,55,129, _
  106,77,135,104,0,4,208,0,95,96, _
  96,99,119,140,14,148,175,63,206,11, _
  30,200,27,197,232,140,242,193,38,0, _
  0,122,202,80,21,4,18,69,183,100, _
  0,0,75,183,236,252,235,174,49,0 , _
0 }

' Font data for character 65 ('A')
Static Shared As UByte font_arial_10_regular_char_65_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,119,236,8,0,0, _
  0,0,0,207,150,96,0,0, _
  0,0,64,161,30,201,0,0, _
  0,0,164,61,0,183,55,0, _
  0,17,247,255,255,255,163,0, _
  0,109,148,0,0,17,238,21, _
  0,209,46,0,0,0,154,122, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 66 ('B')
Static Shared As UByte font_arial_10_regular_char_66_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  68,255,255,252,214,55,0, _
  68,176,0,4,105,187,0, _
  68,176,0,3,100,95,0, _
  68,255,255,255,253,137,0, _
  68,176,0,2,51,246,20, _
  68,176,0,0,45,233,5, _
  68,255,255,252,220,85,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 67 ('C')
Static Shared As UByte font_arial_10_regular_char_67_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,41,184,244,232,129,1, _
  16,226,97,11,30,192,107, _
  95,168,0,0,0,22,31, _
  121,128,0,0,0,0,0, _
  90,164,0,0,0,36,90, _
  14,229,94,10,34,192,112, _
  0,51,196,246,231,129,1, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 68 ('D')
Static Shared As UByte font_arial_10_regular_char_68_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  60,255,255,253,221,94,0, _
  60,184,0,3,52,226,62, _
  60,184,0,0,0,109,147, _
  60,184,0,0,0,80,168, _
  60,184,0,0,0,116,139, _
  60,184,0,3,52,230,49, _
  60,255,255,251,217,90,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 69 ('E')
Static Shared As UByte font_arial_10_regular_char_69_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  52,255,255,255,255,248,0, _
  52,188,0,0,0,0,0, _
  52,188,0,0,0,0,0, _
  52,255,255,255,255,180,0, _
  52,188,0,0,0,0,0, _
  52,188,0,0,0,0,0, _
  52,255,255,255,255,255,36, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 70 ('F')
Static Shared As UByte font_arial_10_regular_char_70_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  44,255,255,255,255,168, _
  44,196,0,0,0,0, _
  44,196,0,0,0,0, _
  44,255,255,255,255,32, _
  44,196,0,0,0,0, _
  44,196,0,0,0,0, _
  44,196,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 71 ('G')
Static Shared As UByte font_arial_10_regular_char_71_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,30,171,239,238,186,44,0, _
  7,218,125,24,14,97,205,0, _
  79,182,0,0,0,0,16,0, _
  112,138,0,0,224,255,255,40, _
  82,179,0,0,0,0,200,40, _
  8,218,122,20,17,80,235,34, _
  0,28,165,236,247,193,69,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 72 ('H')
Static Shared As UByte font_arial_10_regular_char_72_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  52,192,0,0,0,136,108, _
  52,192,0,0,0,136,108, _
  52,192,0,0,0,136,108, _
  52,255,255,255,255,255,108, _
  52,192,0,0,0,136,108, _
  52,192,0,0,0,136,108, _
  52,192,0,0,0,136,108, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 73 ('I')
Static Shared As UByte font_arial_10_regular_char_73_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  16,224,0, _
  16,224,0, _
  16,224,0, _
  16,224,0, _
  16,224,0, _
  16,224,0, _
  16,224,0, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 74 ('J')
Static Shared As UByte font_arial_10_regular_char_74_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,184,56, _
  0,0,0,184,56, _
  0,0,0,184,56, _
  0,0,0,184,56, _
  0,0,0,185,55, _
  157,90,26,226,32, _
  58,222,237,132,0, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 75 ('K')
Static Shared As UByte font_arial_10_regular_char_75_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  68,176,0,0,70,216,33, _
  68,176,0,63,212,31,0, _
  68,176,56,208,29,0,0, _
  68,213,215,219,17,0,0, _
  68,241,44,126,180,1,0, _
  68,176,0,2,185,125,0, _
  68,176,0,0,21,225,70, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 76 ('L')
Static Shared As UByte font_arial_10_regular_char_76_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  68,176,0,0,0,0, _
  68,176,0,0,0,0, _
  68,176,0,0,0,0, _
  68,176,0,0,0,0, _
  68,176,0,0,0,0, _
  68,176,0,0,0,0, _
  68,255,255,255,255,52, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 77 ('M')
Static Shared As UByte font_arial_10_regular_char_77_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  64,255,86,0,0,0,223,148, _
  64,212,171,0,0,57,211,148, _
  64,168,202,11,0,144,123,148, _
  64,168,125,86,2,175,88,148, _
  64,168,36,171,65,113,88,148, _
  64,168,0,194,160,27,88,148, _
  64,168,0,116,190,0,88,148, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 78 ('N')
Static Shared As UByte font_arial_10_regular_char_78_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  60,242,30,0,0,128,104, _
  60,220,182,0,0,128,104, _
  60,172,141,100,0,128,104, _
  60,172,9,203,29,128,104, _
  60,172,0,59,181,128,104, _
  60,172,0,0,143,217,104, _
  60,172,0,0,9,219,104, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 79 ('O')
Static Shared As UByte font_arial_10_regular_char_79_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,33,176,237,237,156,17,0, _
  9,220,109,17,23,147,191,0, _
  87,167,0,0,0,1,212,44, _
  122,125,0,0,0,0,173,76, _
  95,165,0,0,0,2,216,46, _
  13,225,110,17,25,150,194,0, _
  0,36,181,243,238,159,19,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 80 ('P')
Static Shared As UByte font_arial_10_regular_char_80_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  60,255,255,254,235,122,0, _
  60,184,0,0,32,231,32, _
  60,184,0,1,37,228,31, _
  60,255,255,253,226,112,0, _
  60,184,0,0,0,0,0, _
  60,184,0,0,0,0,0, _
  60,184,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 81 ('Q')
Static Shared As UByte font_arial_10_regular_char_81_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,41,184,244,235,154,16,0, _
  19,228,100,15,30,170,187,0, _
  106,154,0,0,0,8,236,38, _
  137,114,0,0,0,0,188,65, _
  106,156,0,0,49,0,209,28, _
  19,228,102,24,200,101,146,0, _
  0,41,185,245,237,188,230,56, _
  0,0,0,0,0,0,42,21, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 82 ('R')
Static Shared As UByte font_arial_10_regular_char_82_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  56,255,255,255,246,182,14,0, _
  56,188,0,0,17,180,108,0, _
  56,188,0,0,19,187,105,0, _
  56,255,255,255,247,167,9,0, _
  56,188,0,37,198,58,0,0, _
  56,188,0,0,42,230,30,0, _
  56,188,0,0,0,111,190,1, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 83 ('S')
Static Shared As UByte font_arial_10_regular_char_83_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,126,221,241,192,49,0, _
  50,213,31,6,81,207,0, _
  25,216,69,9,0,0,0, _
  0,50,152,207,195,69,0, _
  0,0,0,0,34,232,14, _
  107,176,33,6,40,223,13, _
  5,143,231,251,215,78,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 84 ('T')
Static Shared As UByte font_arial_10_regular_char_84_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  196,255,255,255,255,232, _
  0,0,104,140,0,0, _
  0,0,104,140,0,0, _
  0,0,104,140,0,0, _
  0,0,104,140,0,0, _
  0,0,104,140,0,0, _
  0,0,104,140,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 85 ('U')
Static Shared As UByte font_arial_10_regular_char_85_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  56,188,0,0,0,136,108, _
  56,188,0,0,0,136,108, _
  56,188,0,0,0,136,108, _
  56,188,0,0,0,136,107, _
  47,200,0,0,0,154,98, _
  9,238,83,10,48,231,46, _
  0,76,214,249,226,109,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 86 ('V')
Static Shared As UByte font_arial_10_regular_char_86_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  194,60,0,0,0,143,100, _
  92,151,0,0,3,218,11, _
  8,219,5,0,72,152,0, _
  0,146,76,0,165,50,0, _
  0,45,167,12,192,0,0, _
  0,0,190,102,101,0,0, _
  0,0,99,222,12,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 87 ('W')
Static Shared As UByte font_arial_10_regular_char_87_data(...) = { _
  10, 12, _
  0,0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0,0, _
  190,54,0,6,241,117,0,0,193,47, _
  120,116,0,68,153,190,0,8,223,0, _
  51,177,0,142,59,200,16,66,159,0, _
  2,217,1,200,4,133,85,131,87,0, _
  0,169,77,173,0,62,140,190,18,0, _
  0,100,193,102,0,5,182,188,0,0, _
  0,31,255,31,0,0,174,127,0,0, _
  0,0,0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 88 ('X')
Static Shared As UByte font_arial_10_regular_char_88_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  69,211,11,0,28,213,28, _
  0,139,162,7,201,74,0, _
  0,5,204,190,137,0,0, _
  0,0,99,253,34,0,0, _
  0,30,214,113,195,3,0, _
  6,199,72,0,161,130,0, _
  146,141,0,0,13,218,64, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 89 ('Y')
Static Shared As UByte font_arial_10_regular_char_89_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  161,136,0,0,8,210,63, _
  15,224,61,0,144,135,0, _
  0,68,221,76,203,5,0, _
  0,0,149,242,39,0,0, _
  0,0,56,188,0,0,0, _
  0,0,56,188,0,0,0, _
  0,0,56,188,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0 , _
0 }

' Font data for character 90 ('Z')
Static Shared As UByte font_arial_10_regular_char_90_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  100,255,255,255,255,192, _
  0,0,0,24,215,81, _
  0,0,10,202,111,0, _
  0,1,174,142,0,0, _
  0,139,171,2,0,0, _
  101,193,8,0,0,0, _
  204,255,255,255,255,220, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 91 ('[')
Static Shared As UByte font_arial_10_regular_char_91_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  84,255,160, _
  84,144,0, _
  84,144,0, _
  84,144,0, _
  84,144,0, _
  84,144,0, _
  84,144,0, _
  84,144,0, _
  84,255,160 , _
0 }

' Font data for character 92 ('\')
Static Shared As UByte font_arial_10_regular_char_92_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  180,0,0, _
  143,37,0, _
  67,113,0, _
  5,174,0, _
  0,165,14, _
  0,95,85, _
  0,21,158, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 93 (']')
Static Shared As UByte font_arial_10_regular_char_93_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  208,255,32, _
  0,192,32, _
  0,192,32, _
  0,192,32, _
  0,192,32, _
  0,192,32, _
  0,192,32, _
  0,192,32, _
  208,255,32 , _
0 }

' Font data for character 94 ('^')
Static Shared As UByte font_arial_10_regular_char_94_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,60,229,5,0, _
  0,169,155,88,0, _
  27,188,21,191,0, _
  133,93,0,167,52, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 95 ('_')
Static Shared As UByte font_arial_10_regular_char_95_data(...) = { _
  7, 12, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0, _
  40,255,255,255,255,255,172 , _
0 }

' Font data for character 96 ('`')
Static Shared As UByte font_arial_10_regular_char_96_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  72,197,0, _
  0,182,27, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 97 ('a')
Static Shared As UByte font_arial_10_regular_char_97_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  5,149,236,224,74,0, _
  89,164,9,61,200,0, _
  18,141,190,230,219,0, _
  143,157,51,101,222,0, _
  71,230,234,124,213,8, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 98 ('b')
Static Shared As UByte font_arial_10_regular_char_98_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  88,136,0,0,0,0, _
  88,136,0,0,0,0, _
  88,171,217,225,80,0, _
  88,202,23,52,229,6, _
  88,124,0,0,202,29, _
  88,196,21,55,225,3, _
  88,166,229,222,70,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 99 ('c')
Static Shared As UByte font_arial_10_regular_char_99_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  8,166,245,207,36, _
  109,168,15,100,172, _
  148,85,0,0,0, _
  107,166,14,71,190, _
  7,165,243,210,44, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 100 ('d')
Static Shared As UByte font_arial_10_regular_char_100_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,8,216,0, _
  0,0,0,8,216,0, _
  14,181,246,140,216,0, _
  116,155,11,96,216,0, _
  159,73,0,3,214,0, _
  119,162,13,91,215,0, _
  5,167,247,150,208,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 101 ('e')
Static Shared As UByte font_arial_10_regular_char_101_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  6,159,241,215,59,0, _
  109,160,13,45,213,0, _
  154,255,255,255,255,25, _
  113,148,20,0,0,0, _
  8,163,241,239,151,2, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 102 ('f')
Static Shared As UByte font_arial_10_regular_char_102_data(...) = { _
  4, 12, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  4,188,244,14, _
  30,210,9,0, _
  232,255,192,0, _
  32,192,0,0, _
  32,192,0,0, _
  32,192,0,0, _
  32,192,0,0, _
  0,0,0,0, _
  0,0,0,0 , _
0 }

' Font data for character 103 ('g')
Static Shared As UByte font_arial_10_regular_char_103_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  13,180,243,147,208,0, _
  123,153,12,87,228,0, _
  164,65,0,0,218,0, _
  120,152,11,84,228,0, _
  13,176,240,138,223,0, _
  108,151,8,98,194,0, _
  16,188,248,213,55,0 , _
0 }

' Font data for character 104 ('h')
Static Shared As UByte font_arial_10_regular_char_104_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  88,136,0,0,0,0, _
  88,136,0,0,0,0, _
  88,171,209,232,95,0, _
  88,212,29,59,217,0, _
  88,141,0,0,228,0, _
  88,136,0,0,228,0, _
  88,136,0,0,228,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 105 ('i')
Static Shared As UByte font_arial_10_regular_char_105_data(...) = { _
  2, 12, _
  0,0, _
  0,0, _
  0,0, _
  84,140, _
  0,0, _
  84,140, _
  84,140, _
  84,140, _
  84,140, _
  84,140, _
  0,0, _
  0,0 , _
0 }

' Font data for character 106 ('j')
Static Shared As UByte font_arial_10_regular_char_106_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  0,88,136, _
  0,0,0, _
  0,88,136, _
  0,88,136, _
  0,88,136, _
  0,88,136, _
  0,88,136, _
  3,110,130, _
  90,239,60 , _
0 }

' Font data for character 107 ('k')
Static Shared As UByte font_arial_10_regular_char_107_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  84,140,0,0,0, _
  84,140,0,0,0, _
  84,140,23,198,70, _
  84,170,206,58,0, _
  84,233,208,60,0, _
  84,140,43,215,13, _
  84,140,0,118,158, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 108 ('l')
Static Shared As UByte font_arial_10_regular_char_108_data(...) = { _
  2, 12, _
  0,0, _
  0,0, _
  0,0, _
  92,132, _
  92,132, _
  92,132, _
  92,132, _
  92,132, _
  92,132, _
  92,132, _
  0,0, _
  0,0 , _
0 }

' Font data for character 109 ('m')
Static Shared As UByte font_arial_10_regular_char_109_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  88,152,222,227,65,214,236,73, _
  88,209,24,111,217,25,95,168, _
  88,139,0,68,162,0,48,176, _
  88,136,0,68,160,0,48,176, _
  88,136,0,68,160,0,48,176, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 110 ('n')
Static Shared As UByte font_arial_10_regular_char_110_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  88,182,223,237,97,0, _
  88,207,23,64,216,0, _
  88,140,0,1,224,0, _
  88,136,0,0,224,0, _
  88,136,0,0,224,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 111 ('o')
Static Shared As UByte font_arial_10_regular_char_111_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  8,168,243,219,74,0, _
  119,162,14,54,229,9, _
  161,70,0,0,194,40, _
  120,162,14,54,234,13, _
  10,168,243,225,86,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 112 ('p')
Static Shared As UByte font_arial_10_regular_char_112_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  88,160,226,231,87,0, _
  88,204,25,50,229,7, _
  88,125,0,0,198,32, _
  88,198,20,51,225,6, _
  88,180,223,225,75,0, _
  88,136,0,0,0,0, _
  88,136,0,0,0,0 , _
0 }

' Font data for character 113 ('q')
Static Shared As UByte font_arial_10_regular_char_113_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  13,181,246,144,204,0, _
  121,157,12,101,215,0, _
  155,73,0,2,212,0, _
  109,162,13,88,216,0, _
  7,165,243,151,216,0, _
  0,0,0,8,216,0, _
  0,0,0,8,216,0 , _
0 }

' Font data for character 114 ('r')
Static Shared As UByte font_arial_10_regular_char_114_data(...) = { _
  4, 12, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  88,177,236,76, _
  88,200,18,7, _
  88,141,0,0, _
  88,136,0,0, _
  88,136,0,0, _
  0,0,0,0, _
  0,0,0,0 , _
0 }

' Font data for character 115 ('s')
Static Shared As UByte font_arial_10_regular_char_115_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  37,210,247,207,39, _
  123,162,38,0,0, _
  27,182,249,220,50, _
  0,0,10,141,141, _
  82,226,248,197,34, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 116 ('t')
Static Shared As UByte font_arial_10_regular_char_116_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  14,105,0, _
  44,176,0, _
  212,255,148, _
  44,176,0, _
  44,176,0, _
  43,186,5, _
  16,223,158, _
  0,0,0, _
  0,0,0 , _
0 }

' Font data for character 117 ('u')
Static Shared As UByte font_arial_10_regular_char_117_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  92,132,0,8,216,0, _
  92,132,0,8,216,0, _
  92,132,0,11,216,0, _
  84,183,16,106,215,0, _
  14,193,245,138,200,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

' Font data for character 118 ('v')
Static Shared As UByte font_arial_10_regular_char_118_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  174,62,0,53,177, _
  73,157,0,150,76, _
  2,211,18,211,3, _
  0,127,169,130,0, _
  0,29,251,32,0, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 119 ('w')
Static Shared As UByte font_arial_10_regular_char_119_data(...) = { _
  8, 12, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0, _
  206,23,6,243,50,0,206,7, _
  127,96,68,190,121,45,166,0, _
  46,172,141,63,188,125,83,0, _
  0,205,190,1,194,192,10,0, _
  0,140,169,0,134,173,0,0, _
  0,0,0,0,0,0,0,0, _
  0,0,0,0,0,0,0,0 , _
0 }

' Font data for character 120 ('x')
Static Shared As UByte font_arial_10_regular_char_120_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  108,174,1,168,109, _
  0,178,180,178,0, _
  0,56,255,60,0, _
  6,200,111,204,7, _
  142,127,0,128,144, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 121 ('y')
Static Shared As UByte font_arial_10_regular_char_121_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  164,77,0,42,181, _
  60,178,0,141,83, _
  0,207,31,213,6, _
  0,108,191,142,0, _
  0,15,247,44,0, _
  4,54,197,0,0, _
  99,232,56,0,0 , _
0 }

' Font data for character 122 ('z')
Static Shared As UByte font_arial_10_regular_char_122_data(...) = { _
  5, 12, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  0,0,0,0,0, _
  156,255,255,255,156, _
  0,0,39,187,27, _
  0,50,192,24,0, _
  63,189,21,0,0, _
  203,255,255,255,200, _
  0,0,0,0,0, _
  0,0,0,0,0 , _
0 }

' Font data for character 123 ('{')
Static Shared As UByte font_arial_10_regular_char_123_data(...) = { _
  4, 12, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  0,94,246,28, _
  0,176,53,0, _
  0,186,25,0, _
  22,213,7,0, _
  184,120,0,0, _
  22,217,6,0, _
  0,186,26,0, _
  0,175,55,0, _
  0,89,244,28 , _
0 }

' Font data for character 124 ('|')
Static Shared As UByte font_arial_10_regular_char_124_data(...) = { _
  3, 12, _
  0,0,0, _
  0,0,0, _
  0,0,0, _
  20,176,0, _
  20,176,0, _
  20,176,0, _
  20,176,0, _
  20,176,0, _
  20,176,0, _
  20,176,0, _
  20,176,0, _
  20,176,0 , _
0 }

' Font data for character 125 ('}')
Static Shared As UByte font_arial_10_regular_char_125_data(...) = { _
  4, 12, _
  0,0,0,0, _
  0,0,0,0, _
  0,0,0,0, _
  192,168,0,0, _
  6,219,5,0, _
  0,198,14,0, _
  0,168,79,0, _
  0,45,247,16, _
  0,161,80,0, _
  0,197,14,0, _
  6,217,6,0, _
  193,169,0,0 , _
0 }

' Font data for character 126 ('~')
Static Shared As UByte font_arial_10_regular_char_126_data(...) = { _
  6, 12, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  53,228,200,63,37,81, _
  93,25,82,220,215,31, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0, _
  0,0,0,0,0,0 , _
0 }

Sub font_arial_10_regular_init_pointers()
    /'
        The drawing backend indexes printable ASCII characters
        directly by character code. Each pointer references one
        generated width, height, alpha-data block.
    '/
    font_arial_10_regular_chars(32) = @font_arial_10_regular_char_32_data(0)
    font_arial_10_regular_chars(33) = @font_arial_10_regular_char_33_data(0)
    font_arial_10_regular_chars(34) = @font_arial_10_regular_char_34_data(0)
    font_arial_10_regular_chars(35) = @font_arial_10_regular_char_35_data(0)
    font_arial_10_regular_chars(36) = @font_arial_10_regular_char_36_data(0)
    font_arial_10_regular_chars(37) = @font_arial_10_regular_char_37_data(0)
    font_arial_10_regular_chars(38) = @font_arial_10_regular_char_38_data(0)
    font_arial_10_regular_chars(39) = @font_arial_10_regular_char_39_data(0)
    font_arial_10_regular_chars(40) = @font_arial_10_regular_char_40_data(0)
    font_arial_10_regular_chars(41) = @font_arial_10_regular_char_41_data(0)
    font_arial_10_regular_chars(42) = @font_arial_10_regular_char_42_data(0)
    font_arial_10_regular_chars(43) = @font_arial_10_regular_char_43_data(0)
    font_arial_10_regular_chars(44) = @font_arial_10_regular_char_44_data(0)
    font_arial_10_regular_chars(45) = @font_arial_10_regular_char_45_data(0)
    font_arial_10_regular_chars(46) = @font_arial_10_regular_char_46_data(0)
    font_arial_10_regular_chars(47) = @font_arial_10_regular_char_47_data(0)
    font_arial_10_regular_chars(48) = @font_arial_10_regular_char_48_data(0)
    font_arial_10_regular_chars(49) = @font_arial_10_regular_char_49_data(0)
    font_arial_10_regular_chars(50) = @font_arial_10_regular_char_50_data(0)
    font_arial_10_regular_chars(51) = @font_arial_10_regular_char_51_data(0)
    font_arial_10_regular_chars(52) = @font_arial_10_regular_char_52_data(0)
    font_arial_10_regular_chars(53) = @font_arial_10_regular_char_53_data(0)
    font_arial_10_regular_chars(54) = @font_arial_10_regular_char_54_data(0)
    font_arial_10_regular_chars(55) = @font_arial_10_regular_char_55_data(0)
    font_arial_10_regular_chars(56) = @font_arial_10_regular_char_56_data(0)
    font_arial_10_regular_chars(57) = @font_arial_10_regular_char_57_data(0)
    font_arial_10_regular_chars(58) = @font_arial_10_regular_char_58_data(0)
    font_arial_10_regular_chars(59) = @font_arial_10_regular_char_59_data(0)
    font_arial_10_regular_chars(60) = @font_arial_10_regular_char_60_data(0)
    font_arial_10_regular_chars(61) = @font_arial_10_regular_char_61_data(0)
    font_arial_10_regular_chars(62) = @font_arial_10_regular_char_62_data(0)
    font_arial_10_regular_chars(63) = @font_arial_10_regular_char_63_data(0)
    font_arial_10_regular_chars(64) = @font_arial_10_regular_char_64_data(0)
    font_arial_10_regular_chars(65) = @font_arial_10_regular_char_65_data(0)
    font_arial_10_regular_chars(66) = @font_arial_10_regular_char_66_data(0)
    font_arial_10_regular_chars(67) = @font_arial_10_regular_char_67_data(0)
    font_arial_10_regular_chars(68) = @font_arial_10_regular_char_68_data(0)
    font_arial_10_regular_chars(69) = @font_arial_10_regular_char_69_data(0)
    font_arial_10_regular_chars(70) = @font_arial_10_regular_char_70_data(0)
    font_arial_10_regular_chars(71) = @font_arial_10_regular_char_71_data(0)
    font_arial_10_regular_chars(72) = @font_arial_10_regular_char_72_data(0)
    font_arial_10_regular_chars(73) = @font_arial_10_regular_char_73_data(0)
    font_arial_10_regular_chars(74) = @font_arial_10_regular_char_74_data(0)
    font_arial_10_regular_chars(75) = @font_arial_10_regular_char_75_data(0)
    font_arial_10_regular_chars(76) = @font_arial_10_regular_char_76_data(0)
    font_arial_10_regular_chars(77) = @font_arial_10_regular_char_77_data(0)
    font_arial_10_regular_chars(78) = @font_arial_10_regular_char_78_data(0)
    font_arial_10_regular_chars(79) = @font_arial_10_regular_char_79_data(0)
    font_arial_10_regular_chars(80) = @font_arial_10_regular_char_80_data(0)
    font_arial_10_regular_chars(81) = @font_arial_10_regular_char_81_data(0)
    font_arial_10_regular_chars(82) = @font_arial_10_regular_char_82_data(0)
    font_arial_10_regular_chars(83) = @font_arial_10_regular_char_83_data(0)
    font_arial_10_regular_chars(84) = @font_arial_10_regular_char_84_data(0)
    font_arial_10_regular_chars(85) = @font_arial_10_regular_char_85_data(0)
    font_arial_10_regular_chars(86) = @font_arial_10_regular_char_86_data(0)
    font_arial_10_regular_chars(87) = @font_arial_10_regular_char_87_data(0)
    font_arial_10_regular_chars(88) = @font_arial_10_regular_char_88_data(0)
    font_arial_10_regular_chars(89) = @font_arial_10_regular_char_89_data(0)
    font_arial_10_regular_chars(90) = @font_arial_10_regular_char_90_data(0)
    font_arial_10_regular_chars(91) = @font_arial_10_regular_char_91_data(0)
    font_arial_10_regular_chars(92) = @font_arial_10_regular_char_92_data(0)
    font_arial_10_regular_chars(93) = @font_arial_10_regular_char_93_data(0)
    font_arial_10_regular_chars(94) = @font_arial_10_regular_char_94_data(0)
    font_arial_10_regular_chars(95) = @font_arial_10_regular_char_95_data(0)
    font_arial_10_regular_chars(96) = @font_arial_10_regular_char_96_data(0)
    font_arial_10_regular_chars(97) = @font_arial_10_regular_char_97_data(0)
    font_arial_10_regular_chars(98) = @font_arial_10_regular_char_98_data(0)
    font_arial_10_regular_chars(99) = @font_arial_10_regular_char_99_data(0)
    font_arial_10_regular_chars(100) = @font_arial_10_regular_char_100_data(0)
    font_arial_10_regular_chars(101) = @font_arial_10_regular_char_101_data(0)
    font_arial_10_regular_chars(102) = @font_arial_10_regular_char_102_data(0)
    font_arial_10_regular_chars(103) = @font_arial_10_regular_char_103_data(0)
    font_arial_10_regular_chars(104) = @font_arial_10_regular_char_104_data(0)
    font_arial_10_regular_chars(105) = @font_arial_10_regular_char_105_data(0)
    font_arial_10_regular_chars(106) = @font_arial_10_regular_char_106_data(0)
    font_arial_10_regular_chars(107) = @font_arial_10_regular_char_107_data(0)
    font_arial_10_regular_chars(108) = @font_arial_10_regular_char_108_data(0)
    font_arial_10_regular_chars(109) = @font_arial_10_regular_char_109_data(0)
    font_arial_10_regular_chars(110) = @font_arial_10_regular_char_110_data(0)
    font_arial_10_regular_chars(111) = @font_arial_10_regular_char_111_data(0)
    font_arial_10_regular_chars(112) = @font_arial_10_regular_char_112_data(0)
    font_arial_10_regular_chars(113) = @font_arial_10_regular_char_113_data(0)
    font_arial_10_regular_chars(114) = @font_arial_10_regular_char_114_data(0)
    font_arial_10_regular_chars(115) = @font_arial_10_regular_char_115_data(0)
    font_arial_10_regular_chars(116) = @font_arial_10_regular_char_116_data(0)
    font_arial_10_regular_chars(117) = @font_arial_10_regular_char_117_data(0)
    font_arial_10_regular_chars(118) = @font_arial_10_regular_char_118_data(0)
    font_arial_10_regular_chars(119) = @font_arial_10_regular_char_119_data(0)
    font_arial_10_regular_chars(120) = @font_arial_10_regular_char_120_data(0)
    font_arial_10_regular_chars(121) = @font_arial_10_regular_char_121_data(0)
    font_arial_10_regular_chars(122) = @font_arial_10_regular_char_122_data(0)
    font_arial_10_regular_chars(123) = @font_arial_10_regular_char_123_data(0)
    font_arial_10_regular_chars(124) = @font_arial_10_regular_char_124_data(0)
    font_arial_10_regular_chars(125) = @font_arial_10_regular_char_125_data(0)
    font_arial_10_regular_chars(126) = @font_arial_10_regular_char_126_data(0)
End Sub

#endif

/' end of font_arial_10_regular.bi '/

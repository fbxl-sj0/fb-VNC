/'
    Project: omaGUI
    ---------------

    File: graphicshape.bas

    Purpose:

        Render generic primitive graphic shapes through the backend drawing
        interface.

    Responsibilities:

        - draw imported HMI graphic element placeholders
        - provide minimal styled line, path, box, ellipse, text, and control rendering
        - provide opt-in pointer and keyboard input for control-shaped elements
        - keep rendering independent from any galaxy extraction format

    This file intentionally does NOT contain:

        - source format parsing
        - animation execution
        - application-specific widget behavior
'/

#lang "fb"

#include once "src/widgets/graphicshape.bi"
#include once "src/widgets/menu.bi"

Const GRAPHICSHAPE_PI As Double = 3.14159265358979323846

/'
    Renderer module state

    The graphics renderer owns this fixed-capacity state. It has static
    lifetime so solid fills can share empty gradient-stop arrays without
    allocating temporary storage for every shape.
'/
Dim Shared graphicshape_empty_gradient_stop_pos(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS) As Integer
Dim Shared graphicshape_empty_gradient_stop_clr(1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS) As ULong

' -------------------------------------------------------------------------
' Local drawing helpers
' -------------------------------------------------------------------------

Private Function graphicshape_ClampAlpha(ByVal alpha As Integer) As Integer
    If alpha < 0 Then Return 0
    If alpha > 255 Then Return 255
    Return alpha
End Function

Private Function graphicshape_CombineAlpha(ByVal object_alpha As Integer, _
                                           ByVal local_alpha As Integer) As Integer
    object_alpha = graphicshape_ClampAlpha(object_alpha)
    local_alpha = graphicshape_ClampAlpha(local_alpha)
    Return (object_alpha * local_alpha) \ 255
End Function

Private Function graphicshape_ClampFillMode(ByVal fill_mode As Integer) As Integer
    Select Case fill_mode
    Case GUI_FILL_SOLID, GUI_FILL_GRADIENT_VERTICAL, _
         GUI_FILL_GRADIENT_HORIZONTAL, GUI_FILL_GRADIENT_EDGE_HORIZONTAL
        Return fill_mode
    Case Else
        Return GUI_FILL_SOLID
    End Select
End Function

Private Function graphicshape_ColorChannel(ByVal clr As ULong, _
                                           ByVal shift_value As Integer) _
                                           As Integer
    Return (clr Shr shift_value) And &HFF
End Function

Private Function graphicshape_BlendColor(ByVal first_clr As ULong, _
                                         ByVal second_clr As ULong, _
                                         ByVal numerator As Integer, _
                                         ByVal denominator As Integer) _
                                         As ULong
    Dim first_weight As Integer
    Dim second_weight As Integer
    Dim red_value As Integer
    Dim green_value As Integer
    Dim blue_value As Integer

    If denominator <= 0 Then
        Return first_clr
    End If

    If numerator < 0 Then numerator = 0
    If numerator > denominator Then numerator = denominator

    first_weight = denominator - numerator
    second_weight = numerator

    red_value = ((graphicshape_ColorChannel(first_clr, 16) * first_weight) + _
                 (graphicshape_ColorChannel(second_clr, 16) * second_weight)) \ _
                denominator
    green_value = ((graphicshape_ColorChannel(first_clr, 8) * first_weight) + _
                   (graphicshape_ColorChannel(second_clr, 8) * second_weight)) \ _
                  denominator
    blue_value = ((graphicshape_ColorChannel(first_clr, 0) * first_weight) + _
                  (graphicshape_ColorChannel(second_clr, 0) * second_weight)) \ _
                 denominator

    Return RGB(red_value, green_value, blue_value)
End Function

Private Function graphicshape_GradientStopColor(ByVal position As Integer, _
                                                ByVal fallback_clr As ULong, _
                                                ByVal stop_count As Integer, _
                                                stop_pos() As Integer, _
                                                stop_clr() As ULong) As ULong
    Dim stop_index As Integer
    Dim left_pos As Integer
    Dim right_pos As Integer
    Dim numerator As Integer
    Dim denominator As Integer

    If stop_count < 2 Then
        Return fallback_clr
    End If

    If stop_count > GRAPHICSHAPE_MAX_GRADIENT_STOPS Then
        stop_count = GRAPHICSHAPE_MAX_GRADIENT_STOPS
    End If

    If position <= stop_pos(1) Then
        Return stop_clr(1)
    End If

    For stop_index = 2 To stop_count
        If position <= stop_pos(stop_index) Then
            left_pos = stop_pos(stop_index - 1)
            right_pos = stop_pos(stop_index)

            If right_pos <= left_pos Then
                Return stop_clr(stop_index)
            End If

            numerator = position - left_pos
            denominator = right_pos - left_pos

            Return graphicshape_BlendColor(stop_clr(stop_index - 1), _
                                           stop_clr(stop_index), _
                                           numerator, denominator)
        End If
    Next stop_index

    Return stop_clr(stop_count)
End Function

Private Function graphicshape_GradientColor(ByVal local_x As Integer, _
                                            ByVal local_y As Integer, _
                                            ByVal w As Integer, _
                                            ByVal h As Integer, _
                                            ByVal fill_mode As Integer, _
                                            ByVal fill_clr As ULong, _
                                            ByVal gradient_clr As ULong, _
                                            ByVal stop_count As Integer, _
                                            stop_pos() As Integer, _
                                            stop_clr() As ULong) _
                                            As ULong
    Dim numerator As Integer
    Dim denominator As Integer
    Dim center_twice As Integer

    Select Case graphicshape_ClampFillMode(fill_mode)
    Case GUI_FILL_GRADIENT_VERTICAL
        denominator = h - 1
        numerator = local_y
    Case GUI_FILL_GRADIENT_HORIZONTAL
        denominator = w - 1
        numerator = local_x
    Case GUI_FILL_GRADIENT_EDGE_HORIZONTAL
        denominator = w - 1
        center_twice = w - 1
        numerator = Abs((local_x * 2) - center_twice)
    Case Else
        Return fill_clr
    End Select

    If denominator <= 0 Then
        Return fill_clr
    End If

    If stop_count >= 2 And _
       (fill_mode = GUI_FILL_GRADIENT_VERTICAL Or _
        fill_mode = GUI_FILL_GRADIENT_HORIZONTAL Or _
        fill_mode = GUI_FILL_GRADIENT_EDGE_HORIZONTAL) Then
        Return graphicshape_GradientStopColor((numerator * 10000) \ denominator, _
                                              fill_clr, stop_count, _
                                              stop_pos(), stop_clr())
    End If

    Return graphicshape_BlendColor(fill_clr, gradient_clr, numerator, _
                                   denominator)
End Function

Private Sub graphicshape_FillSpan(ByVal x1 As Integer, _
                                  ByVal y As Integer, _
                                  ByVal x2 As Integer, _
                                  ByVal base_x As Integer, _
                                  ByVal base_y As Integer, _
                                  ByVal base_w As Integer, _
                                  ByVal base_h As Integer, _
                                  ByVal fill_clr As ULong, _
                                  ByVal gradient_clr As ULong, _
                                  ByVal fill_mode As Integer, _
                                  ByVal stop_count As Integer, _
                                  stop_pos() As Integer, _
                                  stop_clr() As ULong, _
                                  ByVal alpha As Integer)
    Dim px As Integer
    Dim line_clr As ULong

    If alpha <= 0 Or x2 < x1 Then
        Exit Sub
    End If

    fill_mode = graphicshape_ClampFillMode(fill_mode)

    If fill_mode = GUI_FILL_SOLID Then
        backend_LineEx x1, y, x2, y, fill_clr, 1, alpha
        Exit Sub
    End If

    If fill_mode = GUI_FILL_GRADIENT_VERTICAL Then
        line_clr = graphicshape_GradientColor(0, y - base_y, base_w, base_h, _
                                              fill_mode, fill_clr, gradient_clr, _
                                              stop_count, stop_pos(), stop_clr())
        backend_LineEx x1, y, x2, y, line_clr, 1, alpha
        Exit Sub
    End If

    For px = x1 To x2
        line_clr = graphicshape_GradientColor(px - base_x, y - base_y, _
                                              base_w, base_h, fill_mode, _
                                              fill_clr, gradient_clr, _
                                              stop_count, stop_pos(), _
                                              stop_clr())
        backend_PSetAlpha px, y, line_clr, alpha
    Next px
End Sub

Private Sub graphicshape_FillBox(ByVal x As Integer, _
                                 ByVal y As Integer, _
                                 ByVal w As Integer, _
                                 ByVal h As Integer, _
                                 ByVal fill_clr As ULong, _
                                 ByVal gradient_clr As ULong, _
                                 ByVal fill_mode As Integer, _
                                 ByVal stop_count As Integer, _
                                 stop_pos() As Integer, _
                                 stop_clr() As ULong, _
                                 ByVal alpha As Integer)
    Dim local_y As Integer

    If w <= 0 Or h <= 0 Or alpha <= 0 Then
        Exit Sub
    End If

    fill_mode = graphicshape_ClampFillMode(fill_mode)

    If fill_mode = GUI_FILL_SOLID Then
        backend_RectEx x, y, w, h, fill_clr, 1, 1, alpha
        Exit Sub
    End If

    For local_y = 0 To h - 1
        graphicshape_FillSpan x, y + local_y, x + w - 1, x, y, w, h, _
                              fill_clr, gradient_clr, fill_mode, stop_count, _
                              stop_pos(), stop_clr(), alpha
    Next local_y
End Sub

Private Sub graphicshape_NormalizeRenderBox(ByVal shape_kind As Integer, _
                                            ByRef w As Integer, _
                                            ByRef h As Integer)
    If shape_kind = GUI_SHAPE_LINE Or shape_kind = GUI_SHAPE_POLYLINE Or _
       shape_kind = GUI_SHAPE_CONNECTOR Then
        /'
            Line-like primitives use width and height as the delta to the
            second point. Negative and zero deltas are valid; only the
            completely empty segment needs a tiny fallback so it can still be
            represented.
        '/

        If w = 0 And h = 0 Then
            h = 1
        End If
    Else
        If w < 1 Then w = 1
        If h < 1 Then h = 1
    End If
End Sub

Private Sub graphicshape_CopyGradientStops(ByRef d As GraphicShapeData, _
                                           ByRef options As GraphicShapeRenderOptions)
    Dim stop_index As Integer
    Dim sort_index As Integer
    Dim swap_pos As Integer
    Dim swap_clr As ULong

    d.fill_gradient_stop_count = options.fill_gradient_stop_count

    If d.fill_gradient_stop_count < 0 Then
        d.fill_gradient_stop_count = 0
    End If

    If d.fill_gradient_stop_count > GRAPHICSHAPE_MAX_GRADIENT_STOPS Then
        d.fill_gradient_stop_count = GRAPHICSHAPE_MAX_GRADIENT_STOPS
    End If

    For stop_index = 1 To GRAPHICSHAPE_MAX_GRADIENT_STOPS
        d.fill_gradient_stop_pos(stop_index) = options.fill_gradient_stop_pos(stop_index)
        d.fill_gradient_stop_clr(stop_index) = options.fill_gradient_stop_clr(stop_index)

        If d.fill_gradient_stop_pos(stop_index) < 0 Then
            d.fill_gradient_stop_pos(stop_index) = 0
        End If

        If d.fill_gradient_stop_pos(stop_index) > 10000 Then
            d.fill_gradient_stop_pos(stop_index) = 10000
        End If
    Next stop_index

    For stop_index = 1 To d.fill_gradient_stop_count - 1
        For sort_index = stop_index + 1 To d.fill_gradient_stop_count
            If d.fill_gradient_stop_pos(sort_index) < _
               d.fill_gradient_stop_pos(stop_index) Then
                swap_pos = d.fill_gradient_stop_pos(stop_index)
                swap_clr = d.fill_gradient_stop_clr(stop_index)

                d.fill_gradient_stop_pos(stop_index) = _
                    d.fill_gradient_stop_pos(sort_index)
                d.fill_gradient_stop_clr(stop_index) = _
                    d.fill_gradient_stop_clr(sort_index)

                d.fill_gradient_stop_pos(sort_index) = swap_pos
                d.fill_gradient_stop_clr(sort_index) = swap_clr
            End If
        Next sort_index
    Next stop_index
End Sub

Private Sub graphicshape_LoadDataFromOptions(ByRef d As GraphicShapeData, _
                                             ByRef options As GraphicShapeRenderOptions, _
                                             ByVal label As String)
    Dim line_width As Integer = options.line_width

    If line_width < 0 Then line_width = 0

    d.shape_kind = options.shape_kind
    d.stroke_clr = options.stroke_clr
    d.fill_clr = options.fill_clr
    d.fill_gradient_clr = options.fill_gradient_clr
    d.text_clr = options.text_clr
    d.filled = options.filled
    d.fill_mode = graphicshape_ClampFillMode(options.fill_mode)
    d.line_width = line_width
    d.object_alpha = graphicshape_ClampAlpha(options.object_alpha)
    d.stroke_alpha = graphicshape_ClampAlpha(options.stroke_alpha)
    d.fill_alpha = graphicshape_ClampAlpha(options.fill_alpha)
    d.font_id = options.font_id
    d.text_h_align = options.text_h_align
    d.text_v_align = options.text_v_align
    d.text_fit_width = options.text_fit_width
    d.corner_radius = options.corner_radius
    d.clip_to_bounds = options.clip_to_bounds
    d.point_count = 0
    d.label = label
    d.interactive = 0
    d.pressed = 0
    d.pointer_latch = 0
    d.key_latch = 0
    d.value = 0
    d.selected_index = -1
    d.change_count = 0
    d.item_count = 0
    d.change_handler = 0
    d.dropdown_widget = 0
    graphicshape_CopyGradientStops d, options

    If d.corner_radius < 0 Then
        d.corner_radius = 0
    End If
End Sub

Private Function graphicshape_PointInside( _
    ByVal w As Widget Ptr, ByVal mouse_x As Integer, ByVal mouse_y As Integer _
) As Integer
    If w = 0 Then Return 0

    Return IIf( _
        mouse_x >= w->ax AndAlso mouse_x < w->ax + w->w AndAlso _
        mouse_y >= w->ay AndAlso mouse_y < w->ay + w->h, _
        1, 0 _
    )
End Function

Private Function graphicshape_SelectedLabel( _
    ByVal d As GraphicShapeData Ptr _
) As String
    If d = 0 Then Return ""

    If d->selected_index >= 0 AndAlso _
       d->selected_index < d->item_count Then
        Return d->items(d->selected_index)
    End If

    Return d->label
End Function

Private Sub graphicshape_NotifyChange(ByVal w As Widget Ptr)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)
    d->change_count += 1

    If d->change_handler <> 0 Then
        Cast(Sub(ByVal As Widget Ptr), d->change_handler)(w)
    End If
End Sub

Private Function graphicshape_ChoiceIndexFromPoint( _
    ByVal w As Widget Ptr, ByVal d As GraphicShapeData Ptr, _
    ByVal mouse_y As Integer _
) As Integer
    Dim As Integer choice_count
    Dim As Integer local_y

    If w = 0 OrElse d = 0 Then Return -1
    choice_count = d->item_count
    If choice_count <= 0 OrElse w->h <= 0 Then Return -1

    local_y = mouse_y - w->ay
    If local_y < 0 Then local_y = 0
    If local_y >= w->h Then local_y = w->h - 1
    Return (local_y * choice_count) \ w->h
End Function

Private Sub graphicshape_ChangeSelection( _
    ByVal w As Widget Ptr, ByVal new_index As Integer _
)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)
    If d->item_count <= 0 Then Exit Sub

    If new_index < 0 Then new_index = 0
    If new_index >= d->item_count Then new_index = d->item_count - 1
    If d->selected_index = new_index Then Exit Sub

    d->selected_index = new_index
    d->value = new_index
    graphicshape_NotifyChange w
End Sub

Private Sub graphicshape_DropdownSelected( _
    ByVal context As Any Ptr, ByVal selected_index As Integer _
)
    Dim As Widget Ptr owner = Cast(Widget Ptr, context)
    Dim As GraphicShapeData Ptr d

    If owner = 0 OrElse owner->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, owner->data)
    graphicshape_ChangeSelection owner, selected_index

    If d->dropdown_widget <> 0 Then d->dropdown_widget->visible = 0
    gui_SetFocus owner
End Sub

Private Sub graphicshape_CloseDropdown(ByVal w As Widget Ptr)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)
    If d->dropdown_widget <> 0 Then d->dropdown_widget->visible = 0
End Sub

Private Sub graphicshape_OpenDropdown(ByVal w As Widget Ptr)
    Dim As Integer clientBottom
    Dim As Integer clientTop
    Dim As Widget Ptr container
    Dim As GraphicShapeData Ptr d
    Dim As Widget Ptr dropdownWidget

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)
    If d->item_count <= 0 Then Exit Sub

    dropdownWidget = d->dropdown_widget
    If dropdownWidget = 0 Then
        dropdownWidget = menu_Create(w->name & "_dropdown", 0, w->h)
        If dropdownWidget = 0 Then Exit Sub

        /'
            Popup menus intentionally receive the first outside click so they
            can dismiss themselves. Parenting the popup to its imported
            control still binds layout, clipping, and destruction to the same
            window tree.
        '/
        dropdownWidget->accepts_focus = -1
        menu_SetSelectionHandler _
            dropdownWidget, @graphicshape_DropdownSelected, w
        gui_AddWidget dropdownWidget
        gui_SetParent dropdownWidget, w
        d->dropdown_widget = dropdownWidget
    End If

    menu_ClearItems dropdownWidget
    dropdownWidget->w = w->w

    For itemIndex As Integer = 0 To d->item_count - 1
        menu_AddItem dropdownWidget, d->items(itemIndex), 0
    Next itemIndex

    dropdownWidget->x = 0
    dropdownWidget->y = w->h
    container = w->parent

    If container <> 0 AndAlso container->clip_children <> 0 Then
        clientTop = container->ay + container->child_clip_y
        clientBottom = container->ay + container->h - _
            container->child_clip_bottom

        If w->ay + w->h + dropdownWidget->h > clientBottom AndAlso _
           w->ay - dropdownWidget->h >= clientTop Then
            dropdownWidget->y = -dropdownWidget->h
        End If
    End If

    dropdownWidget->visible = -1
    gui_BringToFront dropdownWidget
End Sub

Private Sub graphicshape_ToggleDropdown(ByVal w As Widget Ptr)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)

    If d->dropdown_widget <> 0 AndAlso _
       d->dropdown_widget->visible <> 0 Then
        graphicshape_CloseDropdown w
    Else
        graphicshape_OpenDropdown w
    End If
End Sub

Private Sub graphicshape_DrawEllipseBox(ByVal x As Integer, ByVal y As Integer, _
                                        ByVal w As Integer, ByVal h As Integer, _
                                        ByVal stroke_clr As ULong, _
                                        ByVal fill_clr As ULong, _
                                        ByVal filled As Integer, _
                                        ByVal line_width As Integer, _
                                        ByVal stroke_alpha As Integer, _
                                        ByVal fill_alpha As Integer)
    Dim As Double cx = x + (w / 2.0)
    Dim As Double cy = y + (h / 2.0)
    Dim As Double rx = w / 2.0
    Dim As Double ry = h / 2.0
    Dim As Double angle
    Dim As Integer old_x = 0
    Dim As Integer old_y = 0
    Dim As Integer px
    Dim As Integer py
    Dim As Integer i
    Dim As Integer yy
    Dim As Double y_ratio
    Dim As Integer span

    If w <= 1 Or h <= 1 Then
        If filled <> 0 Then
            backend_RectEx(x, y, w, h, fill_clr, 1, line_width, fill_alpha)
        End If

        backend_RectEx(x, y, w, h, stroke_clr, 0, line_width, stroke_alpha)
        Exit Sub
    End If

    If filled <> 0 Then
        For yy = -CInt(ry) To CInt(ry)
            If ry <> 0 Then
                y_ratio = yy / ry
            Else
                y_ratio = 0
            End If

            If y_ratio >= -1.0 And y_ratio <= 1.0 Then
                span = CInt(rx * Sqr(1.0 - (y_ratio * y_ratio)))
                backend_LineEx(CInt(cx) - span, CInt(cy) + yy, _
                               CInt(cx) + span, CInt(cy) + yy, _
                               fill_clr, 1, fill_alpha)
            End If
        Next yy
    End If

    If line_width <= 0 Or stroke_alpha <= 0 Then
        Exit Sub
    End If

    For i = 0 To 64
        angle = (GRAPHICSHAPE_PI * 2.0 * i) / 64.0
        px = CInt(cx + Cos(angle) * rx)
        py = CInt(cy + Sin(angle) * ry)

        If i > 0 Then
            backend_LineEx(old_x, old_y, px, py, stroke_clr, line_width, stroke_alpha)
        End If

        old_x = px
        old_y = py
    Next i
End Sub

Private Sub graphicshape_DrawVerticalChordBox(ByVal x As Integer, _
                                              ByVal y As Integer, _
                                              ByVal w As Integer, _
                                              ByVal h As Integer, _
                                              ByVal stroke_clr As ULong, _
                                              ByVal fill_clr As ULong, _
                                              ByVal filled As Integer, _
                                              ByVal line_width As Integer, _
                                              ByVal stroke_alpha As Integer, _
                                              ByVal fill_alpha As Integer)
    /'
        A Wonderware chord primitive is commonly used as a side cap on motor
        and pump bodies. When the box is much taller than it is wide, drawing a
        full ellipse produces a bulb instead of the authored cap. This helper
        draws one half of the ellipse plus the chord line. Direction is inferred
        from the sign of width when a transform preserves that information.
    '/

    Dim draw_x As Integer
    Dim draw_w As Integer
    Dim side_sign As Integer
    Dim cx As Double
    Dim cy As Double
    Dim rx As Double
    Dim ry As Double
    Dim local_y As Integer
    Dim span As Integer
    Dim y_ratio As Double
    Dim row_y As Integer
    Dim cap_x As Integer
    Dim edge_x As Integer
    Dim curve_x As Integer
    Dim angle As Double
    Dim start_angle As Double
    Dim end_angle As Double
    Dim old_x As Integer
    Dim old_y As Integer
    Dim px As Integer
    Dim py As Integer
    Dim i As Integer

    If w = 0 Or h <= 1 Then
        Exit Sub
    End If

    draw_x = x
    draw_w = w
    side_sign = 1

    If draw_w < 0 Then
        draw_x = x + draw_w
        draw_w = -draw_w
        side_sign = -1
    End If

    If draw_w <= 1 Then
        backend_LineEx draw_x, y, draw_x, y + h - 1, stroke_clr, _
                       line_width, stroke_alpha
        Exit Sub
    End If

    cx = draw_x + (draw_w / 2.0)
    cy = y + (h / 2.0)
    rx = draw_w / 2.0
    ry = h / 2.0

    If side_sign >= 0 Then
        cap_x = draw_x
    Else
        cap_x = draw_x + draw_w - 1
    End If

    If filled <> 0 And fill_alpha > 0 Then
        For local_y = -CInt(ry) To CInt(ry)
            If ry <> 0 Then
                y_ratio = local_y / ry
            Else
                y_ratio = 0
            End If

            If y_ratio >= -1.0 And y_ratio <= 1.0 Then
                span = CInt(rx * Sqr(1.0 - (y_ratio * y_ratio)))
                row_y = CInt(cy) + local_y

                If side_sign >= 0 Then
                    edge_x = CInt(cx + span)
                    backend_LineEx cap_x, row_y, edge_x, row_y, fill_clr, _
                                   1, fill_alpha
                Else
                    edge_x = CInt(cx - span)
                    backend_LineEx edge_x, row_y, cap_x, row_y, fill_clr, _
                                   1, fill_alpha
                End If
            End If
        Next local_y
    End If

    If line_width <= 0 Or stroke_alpha <= 0 Then
        Exit Sub
    End If

    If side_sign >= 0 Then
        start_angle = -GRAPHICSHAPE_PI / 2.0
        end_angle = GRAPHICSHAPE_PI / 2.0
    Else
        start_angle = GRAPHICSHAPE_PI / 2.0
        end_angle = GRAPHICSHAPE_PI * 1.5
    End If

    For i = 0 To 32
        angle = start_angle + ((end_angle - start_angle) * i / 32.0)
        curve_x = CInt(cx + Cos(angle) * rx)
        py = CInt(cy + Sin(angle) * ry)
        px = curve_x

        If i > 0 Then
            backend_LineEx old_x, old_y, px, py, stroke_clr, line_width, _
                           stroke_alpha
        End If

        old_x = px
        old_y = py
    Next i

    backend_LineEx cap_x, y, cap_x, y + h - 1, stroke_clr, line_width, _
                   stroke_alpha
End Sub

Private Function graphicshape_RoundRectInset(ByVal local_y As Integer, _
                                             ByVal h As Integer, _
                                             ByVal radius As Integer) As Integer
    Dim dy As Integer
    Dim span As Integer

    If radius <= 0 Then
        Return 0
    End If

    If local_y < radius Then
        dy = radius - local_y
    ElseIf local_y >= h - radius Then
        dy = local_y - (h - radius - 1)
    Else
        Return 0
    End If

    If dy <= 0 Then
        Return 0
    End If

    If dy > radius Then
        dy = radius
    End If

    span = CInt(Sqr((radius * radius) - (dy * dy)))
    Return radius - span
End Function

Private Sub graphicshape_FillRoundRectSpans(ByVal x As Integer, _
                                            ByVal y As Integer, _
                                            ByVal w As Integer, _
                                            ByVal h As Integer, _
                                            ByVal radius As Integer, _
                                            ByVal clr As ULong, _
                                            ByVal gradient_clr As ULong, _
                                            ByVal fill_mode As Integer, _
                                            ByVal stop_count As Integer, _
                                            stop_pos() As Integer, _
                                            stop_clr() As ULong, _
                                            ByVal alpha As Integer)
    Dim local_y As Integer
    Dim inset As Integer

    If w <= 0 Or h <= 0 Or alpha <= 0 Then
        Exit Sub
    End If

    If radius < 0 Then radius = 0
    If radius > w \ 2 Then radius = w \ 2
    If radius > h \ 2 Then radius = h \ 2

    If radius = 0 Then
        graphicshape_FillBox x, y, w, h, clr, gradient_clr, fill_mode, _
                             stop_count, stop_pos(), stop_clr(), alpha
        Exit Sub
    End If

    For local_y = 0 To h - 1
        inset = graphicshape_RoundRectInset(local_y, h, radius)
        graphicshape_FillSpan x + inset, y + local_y, x + w - 1 - inset, _
                              x, y, w, h, clr, gradient_clr, fill_mode, _
                              stop_count, stop_pos(), stop_clr(), alpha
    Next local_y
End Sub

Private Sub graphicshape_DrawRoundRectOutline(ByVal x As Integer, _
                                              ByVal y As Integer, _
                                              ByVal w As Integer, _
                                              ByVal h As Integer, _
                                              ByVal radius As Integer, _
                                              ByVal line_width As Integer, _
                                              ByVal clr As ULong, _
                                              ByVal alpha As Integer)
    Dim local_y As Integer
    Dim outer_inset As Integer
    Dim inner_inset As Integer
    Dim inner_y As Integer
    Dim inner_h As Integer
    Dim inner_r As Integer
    Dim outer_left As Integer
    Dim outer_right As Integer
    Dim inner_left As Integer
    Dim inner_right As Integer

    If alpha <= 0 Or line_width <= 0 Then
        Exit Sub
    End If

    If line_width * 2 >= w Or line_width * 2 >= h Then
        graphicshape_FillRoundRectSpans x, y, w, h, radius, clr, clr, _
                                        GUI_FILL_SOLID, 0, _
                                        graphicshape_empty_gradient_stop_pos(), _
                                        graphicshape_empty_gradient_stop_clr(), _
                                        alpha
        Exit Sub
    End If

    inner_h = h - (line_width * 2)
    inner_r = radius - line_width
    If inner_r < 0 Then inner_r = 0

    For local_y = 0 To h - 1
        outer_inset = graphicshape_RoundRectInset(local_y, h, radius)
        outer_left = x + outer_inset
        outer_right = x + w - 1 - outer_inset

        inner_y = local_y - line_width

        If inner_y < 0 Or inner_y >= inner_h Then
            backend_LineEx outer_left, y + local_y, outer_right, y + local_y, _
                           clr, 1, alpha
        Else
            inner_inset = graphicshape_RoundRectInset(inner_y, inner_h, inner_r)
            inner_left = x + line_width + inner_inset
            inner_right = x + w - line_width - 1 - inner_inset

            If outer_left < inner_left Then
                backend_LineEx outer_left, y + local_y, inner_left - 1, _
                               y + local_y, clr, 1, alpha
            End If

            If inner_right < outer_right Then
                backend_LineEx inner_right + 1, y + local_y, outer_right, _
                               y + local_y, clr, 1, alpha
            End If
        End If
    Next local_y
End Sub

Private Sub graphicshape_DrawRoundRectBox(ByVal x As Integer, _
                                          ByVal y As Integer, _
                                          ByVal w As Integer, _
                                          ByVal h As Integer, _
                                          ByVal radius As Integer, _
                                          ByVal stroke_clr As ULong, _
                                          ByVal fill_clr As ULong, _
                                          ByVal fill_gradient_clr As ULong, _
                                          ByVal filled As Integer, _
                                          ByVal fill_mode As Integer, _
                                          ByVal line_width As Integer, _
                                          ByVal stop_count As Integer, _
                                          stop_pos() As Integer, _
                                          stop_clr() As ULong, _
                                          ByVal stroke_alpha As Integer, _
                                          ByVal fill_alpha As Integer)
    /'
        Rounded rectangles must clip the fill to the same rounded silhouette
        as the stroke. Drawing a square fill first leaves sharp pixels in the
        corners, which is especially visible on analog value displays.
    '/

    Dim inner_x As Integer
    Dim inner_y As Integer
    Dim inner_w As Integer
    Dim inner_h As Integer
    Dim inner_r As Integer

    If w <= 0 Or h <= 0 Then
        Exit Sub
    End If

    If radius < 1 Or w < 4 Or h < 4 Then
        If filled <> 0 Then
            graphicshape_FillBox x, y, w, h, fill_clr, fill_gradient_clr, _
                                 fill_mode, stop_count, stop_pos(), _
                                 stop_clr(), fill_alpha
        End If

        If line_width > 0 Then
            backend_RectEx x, y, w, h, stroke_clr, 0, line_width, stroke_alpha
        End If

        Exit Sub
    End If

    If radius > w \ 2 Then radius = w \ 2
    If radius > h \ 2 Then radius = h \ 2

    If filled = 0 Or fill_alpha <= 0 Then
        graphicshape_DrawRoundRectOutline x, y, w, h, radius, line_width, _
                                          stroke_clr, stroke_alpha
        Exit Sub
    End If

    If line_width > 0 And stroke_alpha > 0 Then
        graphicshape_FillRoundRectSpans x, y, w, h, radius, _
                                        stroke_clr, stroke_clr, _
                                        GUI_FILL_SOLID, 0, _
                                        graphicshape_empty_gradient_stop_pos(), _
                                        graphicshape_empty_gradient_stop_clr(), _
                                        stroke_alpha
    End If

    inner_x = x + line_width
    inner_y = y + line_width
    inner_w = w - (line_width * 2)
    inner_h = h - (line_width * 2)
    inner_r = radius - line_width

    If inner_w <= 0 Or inner_h <= 0 Then
        Exit Sub
    End If

    If inner_r < 0 Then inner_r = 0

    graphicshape_FillRoundRectSpans inner_x, inner_y, inner_w, inner_h, _
                                    inner_r, fill_clr, fill_gradient_clr, _
                                    fill_mode, stop_count, stop_pos(), _
                                    stop_clr(), fill_alpha
End Sub

Private Sub graphicshape_DrawPlaceholder(ByVal x As Integer, ByVal y As Integer, _
                                         ByVal w As Integer, ByVal h As Integer, _
                                         ByVal stroke_clr As ULong, _
                                         ByVal line_width As Integer, _
                                         ByVal alpha As Integer, _
                                         ByVal label As String)
    If line_width > 0 And alpha > 0 Then
        backend_RectEx(x, y, w, h, stroke_clr, 0, line_width, alpha)
        backend_LineEx(x, y, x + w, y + h, stroke_clr, line_width, alpha)
        backend_LineEx(x + w, y, x, y + h, stroke_clr, line_width, alpha)
    End If

    If Len(label) > 0 And w > 24 And h > 14 Then
        backend_PrintAlignedAlpha(x + 3, y + 3, w - 6, h - 6, stroke_clr, _
                                  label, BACKEND_FONT_ARIAL_10_REGULAR, _
                                  BACKEND_ALIGN_LEFT, BACKEND_ALIGN_TOP, alpha)
    End If
End Sub

Private Sub graphicshape_DrawControlLabel(ByVal x As Integer, ByVal y As Integer, _
                                          ByVal w As Integer, ByVal h As Integer, _
                                          ByVal clr As ULong, ByVal label As String, _
                                          ByVal font_id As Integer, _
                                          ByVal alpha As Integer)
    If Len(label) = 0 Or w <= 8 Or h <= 8 Then
        Exit Sub
    End If

    If alpha <= 0 Then
        Exit Sub
    End If

    backend_PrintAlignedAlpha x, y, w, h, clr, label, font_id, _
                              BACKEND_ALIGN_LEFT, BACKEND_ALIGN_MIDDLE, alpha
End Sub

Private Function graphicshape_AlignedY(ByVal y As Integer, _
                                       ByVal h As Integer, _
                                       ByVal text_h As Integer, _
                                       ByVal vertical_align As Integer) As Integer
    If vertical_align = BACKEND_ALIGN_MIDDLE Then
        Return y + ((h - text_h) \ 2)
    End If

    If vertical_align = BACKEND_ALIGN_BOTTOM Then
        Return y + h - text_h
    End If

    Return y
End Function

Private Sub graphicshape_PrintAlignedMaybeFit(ByVal x As Integer, _
                                              ByVal y As Integer, _
                                              ByVal w As Integer, _
                                              ByVal h As Integer, _
                                              ByVal clr As ULong, _
                                              ByVal label As String, _
                                              ByVal font_id As Integer, _
                                              ByVal horizontal_align As Integer, _
                                              ByVal vertical_align As Integer, _
                                              ByVal fit_width As Integer, _
                                              ByVal alpha As Integer)
    /'
        Imported HMI tag headers often reserve a fixed text box and rely on
        the platform font metrics to fill it. The small built-in bitmap fonts
        are narrower, so fitted text adds spacing between existing characters
        without altering the label content.
    '/

    Dim text_w As Integer
    Dim text_h As Integer
    Dim draw_y As Integer
    Dim cursor_x As Double
    Dim extra_space As Double
    Dim i As Integer
    Dim ch As String
    Dim ch_w As Integer
    Dim scale_x As Integer
    Dim scale_y As Integer

    If Len(label) = 0 Or w <= 0 Or h <= 0 Or alpha <= 0 Then
        Exit Sub
    End If

    If alpha > 255 Then alpha = 255

    text_w = backend_GetTextWidthFont(label, font_id)
    text_h = backend_GetTextHeightFont(font_id)

    If fit_width = 0 Or Len(label) <= 1 Or text_w <= 0 Or text_w >= w Then
        backend_PrintAlignedAlpha x, y, w, h, clr, label, font_id, _
                                  horizontal_align, vertical_align, alpha
        Exit Sub
    End If

    /'
        When a text box is tall enough, scale the bitmap font before falling
        back to character spacing. Wide screen titles such as "UG Overview"
        should read like large text, while short HMI tag headers still use the
        spacing behavior that compensates for narrow bitmap glyphs.
    '/

    If text_h > 0 And h >= text_h * 2 Then
        scale_x = w \ text_w
        scale_y = h \ text_h

        If scale_x > 1 And scale_y > 1 Then
            If scale_x > 6 Then scale_x = 6
            If scale_y > 6 Then scale_y = 6
            backend_PrintAlignedScaledAlpha x, y, w, h, clr, label, font_id, _
                                            horizontal_align, vertical_align, _
                                            scale_x, scale_y, alpha
            Exit Sub
        End If
    End If

    If InStr(label, " ") > 0 Then
        backend_PrintAlignedAlpha x, y, w, h, clr, label, font_id, _
                                  horizontal_align, vertical_align, alpha
        Exit Sub
    End If

    draw_y = graphicshape_AlignedY(y, h, text_h, vertical_align)
    cursor_x = x
    extra_space = (w - text_w) / CDbl(Len(label) - 1)

    For i = 1 To Len(label)
        ch = Mid(label, i, 1)
        backend_PrintFontAlpha CInt(cursor_x), draw_y, clr, ch, font_id, alpha
        ch_w = backend_GetTextWidthFont(ch, font_id)
        cursor_x += ch_w + extra_space
    Next i
End Sub

Private Sub graphicshape_DrawCheckbox(ByVal x As Integer, ByVal y As Integer, _
                                      ByVal w As Integer, ByVal h As Integer, _
                                      ByVal stroke_clr As ULong, _
                                      ByVal fill_clr As ULong, _
                                      ByVal line_width As Integer, _
                                      ByVal stroke_alpha As Integer, _
                                      ByVal fill_alpha As Integer, _
                                      ByVal label As String, _
                                      ByVal font_id As Integer, _
                                      ByVal checked As Integer)
    Dim box_size As Integer = h - 4

    If box_size > 16 Then box_size = 16
    If box_size < 8 Then box_size = 8

    backend_RectEx x, y + ((h - box_size) \ 2), box_size, box_size, _
                   fill_clr, 1, line_width, fill_alpha
    backend_RectEx x, y + ((h - box_size) \ 2), box_size, box_size, _
                   stroke_clr, 0, line_width, stroke_alpha

    If checked <> 0 Then
        backend_LineEx x + 3, y + (h \ 2), _
            x + (box_size \ 2), y + ((h + box_size) \ 2) - 3, _
            stroke_clr, 2, stroke_alpha
        backend_LineEx x + (box_size \ 2), _
            y + ((h + box_size) \ 2) - 3, _
            x + box_size - 2, y + ((h - box_size) \ 2) + 2, _
            stroke_clr, 2, stroke_alpha
    End If

    graphicshape_DrawControlLabel x + box_size + 4, y, w - box_size - 4, h, _
                                  stroke_clr, label, font_id, stroke_alpha
End Sub

Private Sub graphicshape_DrawComboBox(ByVal x As Integer, ByVal y As Integer, _
                                      ByVal w As Integer, ByVal h As Integer, _
                                      ByVal stroke_clr As ULong, _
                                      ByVal fill_clr As ULong, _
                                      ByVal line_width As Integer, _
                                      ByVal stroke_alpha As Integer, _
                                      ByVal fill_alpha As Integer, _
                                      ByVal label As String, _
                                      ByVal font_id As Integer)
    Dim button_w As Integer = h
    Dim arrow_x As Integer
    Dim arrow_y As Integer

    If button_w < 12 Then button_w = 12
    If button_w > w \ 2 Then button_w = w \ 2

    backend_RectEx x, y, w, h, fill_clr, 1, line_width, fill_alpha
    backend_RectEx x, y, w, h, stroke_clr, 0, line_width, stroke_alpha
    backend_LineEx x + w - button_w, y, x + w - button_w, y + h, _
                   stroke_clr, line_width, stroke_alpha

    arrow_x = x + w - (button_w \ 2)
    arrow_y = y + (h \ 2)
    backend_LineEx arrow_x - 4, arrow_y - 2, arrow_x, arrow_y + 3, _
                   stroke_clr, line_width, stroke_alpha
    backend_LineEx arrow_x, arrow_y + 3, arrow_x + 4, arrow_y - 2, _
                   stroke_clr, line_width, stroke_alpha

    graphicshape_DrawControlLabel x + 3, y, w - button_w - 6, h, _
                                  stroke_clr, label, font_id, stroke_alpha
End Sub

Private Sub graphicshape_DrawListBox(ByVal x As Integer, ByVal y As Integer, _
                                     ByVal w As Integer, ByVal h As Integer, _
                                     ByVal stroke_clr As ULong, _
                                     ByVal fill_clr As ULong, _
                                     ByVal line_width As Integer, _
                                     ByVal stroke_alpha As Integer, _
                                     ByVal fill_alpha As Integer, _
                                     ByVal label As String, _
                                     ByVal font_id As Integer, _
                                     ByVal d As GraphicShapeData Ptr)
    Dim As Integer item_height
    Dim As Integer item_index
    Dim row_y As Integer

    backend_RectEx x, y, w, h, fill_clr, 1, line_width, fill_alpha
    backend_RectEx x, y, w, h, stroke_clr, 0, line_width, stroke_alpha

    If d <> 0 AndAlso d->item_count > 0 Then
        item_height = (h - 2) \ d->item_count
        If item_height < 1 Then item_height = 1

        For item_index = 0 To d->item_count - 1
            row_y = y + 1 + (item_index * item_height)
            If row_y >= y + h - 1 Then Exit For

            If item_index = d->selected_index Then
                backend_RectEx x + 1, row_y, w - 2, item_height, _
                    RGB(180, 210, 245), 1, 1, fill_alpha
            End If

            graphicshape_DrawControlLabel x + 3, row_y, w - 6, _
                item_height, stroke_clr, d->items(item_index), _
                font_id, stroke_alpha
            backend_LineEx x + 2, row_y + item_height - 1, _
                x + w - 3, row_y + item_height - 1, _
                stroke_clr, 1, stroke_alpha \ 3
        Next item_index
    Else
        For row_y = y + 18 To y + h - 4 Step 18
            backend_LineEx x + 2, row_y, x + w - 3, row_y, _
                           stroke_clr, 1, stroke_alpha \ 2
        Next row_y

        graphicshape_DrawControlLabel x + 3, y + 1, w - 6, 16, _
                                      stroke_clr, label, font_id, stroke_alpha
    End If
End Sub

Private Sub graphicshape_DrawCalendarBox(ByVal x As Integer, ByVal y As Integer, _
                                         ByVal w As Integer, ByVal h As Integer, _
                                         ByVal stroke_clr As ULong, _
                                         ByVal fill_clr As ULong, _
                                         ByVal line_width As Integer, _
                                         ByVal stroke_alpha As Integer, _
                                         ByVal fill_alpha As Integer, _
                                         ByVal selected_day As Integer)
    Dim header_h As Integer = 12
    Dim col As Integer
    Dim row As Integer
    Dim grid_top As Integer
    Dim selected_col As Integer
    Dim selected_row As Integer

    If header_h > h \ 3 Then header_h = h \ 3

    backend_RectEx x, y, w, h, fill_clr, 1, line_width, fill_alpha
    backend_RectEx x, y, w, h, stroke_clr, 0, line_width, stroke_alpha
    backend_RectEx x, y, w, header_h, RGB(210, 210, 210), 1, line_width, fill_alpha
    backend_LineEx x, y + header_h, x + w, y + header_h, _
                   stroke_clr, line_width, stroke_alpha

    grid_top = y + header_h

    If selected_day >= 1 AndAlso selected_day <= 31 Then
        selected_col = (selected_day - 1) Mod 7
        selected_row = (selected_day - 1) \ 7
        backend_RectEx _
            x + (selected_col * w \ 7) + 1, _
            grid_top + (selected_row * (h - header_h) \ 5) + 1, _
            (w \ 7) - 1, ((h - header_h) \ 5) - 1, _
            RGB(170, 205, 245), 1, 1, fill_alpha
        backend_PrintFontAlpha x + 3, y, stroke_clr, _
            LTrim(Str(selected_day)), BACKEND_FONT_DEFAULT, stroke_alpha
    End If

    For col = 1 To 6
        backend_LineEx x + (col * w \ 7), grid_top, _
                       x + (col * w \ 7), y + h, _
                       stroke_clr, 1, stroke_alpha \ 3
    Next col

    For row = 1 To 4
        backend_LineEx x, grid_top + (row * (h - header_h) \ 5), _
                       x + w, grid_top + (row * (h - header_h) \ 5), _
                       stroke_clr, 1, stroke_alpha \ 3
    Next row
End Sub

Private Sub graphicshape_DrawRadioButtonGroup(ByVal x As Integer, ByVal y As Integer, _
                                              ByVal w As Integer, ByVal h As Integer, _
                                              ByVal stroke_clr As ULong, _
                                              ByVal fill_clr As ULong, _
                                              ByVal line_width As Integer, _
                                              ByVal stroke_alpha As Integer, _
                                              ByVal fill_alpha As Integer, _
                                              ByVal label As String, _
                                              ByVal font_id As Integer, _
                                              ByVal selected_index As Integer)
    Dim option_y As Integer
    Dim option_step As Integer
    Dim i As Integer

    backend_RectEx x, y, w, h, fill_clr, 1, line_width, fill_alpha
    backend_RectEx x, y, w, h, stroke_clr, 0, line_width, stroke_alpha
    graphicshape_DrawControlLabel x + 3, y + 1, w - 6, 14, _
                                  stroke_clr, label, font_id, stroke_alpha

    option_step = (h - 16) \ 3
    If option_step < 10 Then option_step = 10

    For i = 0 To 2
        option_y = y + 18 + (i * option_step)
        If option_y + 8 >= y + h Then Exit For

        backend_Circle x + 9, option_y + 4, 4, stroke_clr, 0
        If i = selected_index Then
            backend_Circle x + 9, option_y + 4, 2, stroke_clr, 1
        End If
    Next i
End Sub

Private Sub graphicshape_DrawTrendBox(ByVal x As Integer, ByVal y As Integer, _
                                      ByVal w As Integer, ByVal h As Integer, _
                                      ByVal stroke_clr As ULong, _
                                      ByVal fill_clr As ULong, _
                                      ByVal line_width As Integer, _
                                      ByVal stroke_alpha As Integer, _
                                      ByVal fill_alpha As Integer, _
                                      ByVal multi_pen As Integer, _
                                      ByVal marker_value As Integer)
    Dim i As Integer
    Dim y1 As Integer
    Dim y2 As Integer

    backend_RectEx x, y, w, h, fill_clr, 1, line_width, fill_alpha
    backend_RectEx x, y, w, h, stroke_clr, 0, line_width, stroke_alpha

    For i = 1 To 4
        backend_LineEx x + (i * w \ 5), y + 1, x + (i * w \ 5), y + h - 1, _
                       stroke_clr, 1, stroke_alpha \ 4
        backend_LineEx x + 1, y + (i * h \ 5), x + w - 1, y + (i * h \ 5), _
                       stroke_clr, 1, stroke_alpha \ 4
    Next i

    y1 = y + (h * 2 \ 3)
    y2 = y + (h \ 3)
    backend_LineEx x + 4, y1, x + (w \ 3), y2, RGB(0, 120, 200), 1, stroke_alpha
    backend_LineEx x + (w \ 3), y2, x + (w * 2 \ 3), y + (h \ 2), _
                   RGB(0, 120, 200), 1, stroke_alpha
    backend_LineEx x + (w * 2 \ 3), y + (h \ 2), x + w - 4, y + 4, _
                   RGB(0, 120, 200), 1, stroke_alpha

    If multi_pen <> 0 Then
        backend_LineEx x + 4, y + (h \ 3), x + w - 4, y + (h * 2 \ 3), _
                       RGB(200, 80, 80), 1, stroke_alpha
    End If

    If marker_value >= 0 Then
        If marker_value > 100 Then marker_value = 100
        backend_LineEx x + (marker_value * (w - 1) \ 100), y + 1, _
            x + (marker_value * (w - 1) \ 100), y + h - 2, _
            RGB(230, 80, 30), 2, stroke_alpha
    End If
End Sub

Private Sub graphicshape_DrawAlarmClient(ByVal x As Integer, ByVal y As Integer, _
                                         ByVal w As Integer, ByVal h As Integer, _
                                         ByVal stroke_clr As ULong, _
                                         ByVal fill_clr As ULong, _
                                         ByVal line_width As Integer, _
                                         ByVal stroke_alpha As Integer, _
                                         ByVal fill_alpha As Integer, _
                                         ByVal label As String, _
                                         ByVal font_id As Integer)
    Dim row_y As Integer

    backend_RectEx x, y, w, h, fill_clr, 1, line_width, fill_alpha
    backend_RectEx x, y, w, h, stroke_clr, 0, line_width, stroke_alpha
    backend_RectEx x + 1, y + 1, w - 2, 16, RGB(230, 230, 230), 1, 1, fill_alpha
    graphicshape_DrawControlLabel x + 4, y + 1, w - 8, 15, _
                                  stroke_clr, label, font_id, stroke_alpha

    For row_y = y + 18 To y + h - 12 Step 18
        backend_RectEx x + 2, row_y, w - 4, 14, RGB(255, 215, 215), 1, 1, fill_alpha
        backend_LineEx x + 2, row_y + 14, x + w - 3, row_y + 14, _
                       stroke_clr, 1, stroke_alpha \ 3
    Next row_y
End Sub

Private Sub graphicshape_SortHits(hits() As Double, ByVal hit_count As Integer)
    Dim i As Integer
    Dim j As Integer
    Dim temp As Double

    For i = 1 To hit_count - 1
        For j = i + 1 To hit_count
            If hits(j) < hits(i) Then
                temp = hits(i)
                hits(i) = hits(j)
                hits(j) = temp
            End If
        Next j
    Next i
End Sub

Private Sub graphicshape_DrawFilledPath(ByVal x As Integer, ByVal y As Integer, _
                                        ByVal fill_clr As ULong, _
                                        ByVal alpha As Integer, _
                                        ByVal point_count As Integer, _
                                        points_x() As Integer, _
                                        points_y() As Integer)
    /'
        Polygon fill is intentionally small and predictable. The imported
        graphics use ordinary screen-space point lists, so an even-odd
        scanline fill is enough until curved path decoding is added.
    '/

    Dim min_y As Integer
    Dim max_y As Integer
    Dim py As Integer
    Dim i As Integer
    Dim j As Integer
    Dim edge_y1 As Integer
    Dim edge_y2 As Integer
    Dim edge_x1 As Integer
    Dim edge_x2 As Integer
    Dim hit_count As Integer
    Dim hits(1 To GRAPHICSHAPE_MAX_POINTS) As Double

    If alpha <= 0 Or point_count < 3 Then
        Exit Sub
    End If

    min_y = points_y(1)
    max_y = points_y(1)

    For i = 2 To point_count
        If points_y(i) < min_y Then min_y = points_y(i)
        If points_y(i) > max_y Then max_y = points_y(i)
    Next i

    For py = min_y To max_y
        hit_count = 0

        For i = 1 To point_count
            j = i + 1
            If j > point_count Then j = 1

            edge_x1 = points_x(i)
            edge_y1 = points_y(i)
            edge_x2 = points_x(j)
            edge_y2 = points_y(j)

            If edge_y1 = edge_y2 Then
                Continue For
            End If

            If (py >= edge_y1 And py < edge_y2) Or _
               (py >= edge_y2 And py < edge_y1) Then
                If hit_count < GRAPHICSHAPE_MAX_POINTS Then
                    hit_count += 1
                    hits(hit_count) = edge_x1 + _
                                      ((py - edge_y1) * (edge_x2 - edge_x1)) / _
                                      (edge_y2 - edge_y1)
                End If
            End If
        Next i

        If hit_count >= 2 Then
            graphicshape_SortHits hits(), hit_count

            For i = 1 To hit_count - 1 Step 2
                backend_LineEx x + CInt(hits(i)), y + py, _
                               x + CInt(hits(i + 1)), y + py, _
                               fill_clr, 1, alpha
            Next i
        End If
    Next py
End Sub

Private Sub graphicshape_DrawPath(ByVal x As Integer, ByVal y As Integer, _
                                  ByVal stroke_clr As ULong, _
                                  ByVal fill_clr As ULong, _
                                  ByVal filled As Integer, _
                                  ByVal line_width As Integer, _
                                  ByVal stroke_alpha As Integer, _
                                  ByVal fill_alpha As Integer, _
                                  ByVal close_path As Integer, _
                                  ByVal point_count As Integer, _
                                  points_x() As Integer, _
                                  points_y() As Integer)
    Dim i As Integer
    Dim next_i As Integer

    If point_count < 2 Then
        Exit Sub
    End If

    If filled <> 0 And close_path <> 0 Then
        graphicshape_DrawFilledPath x, y, fill_clr, fill_alpha, _
                                    point_count, points_x(), points_y()
    End If

    If line_width <= 0 Or stroke_alpha <= 0 Then
        Exit Sub
    End If

    For i = 1 To point_count - 1
        backend_LineEx x + points_x(i), y + points_y(i), _
                       x + points_x(i + 1), y + points_y(i + 1), _
                       stroke_clr, line_width, stroke_alpha
    Next i

    If close_path <> 0 And point_count >= 3 Then
        next_i = point_count
        backend_LineEx x + points_x(next_i), y + points_y(next_i), _
                       x + points_x(1), y + points_y(1), _
                       stroke_clr, line_width, stroke_alpha
    End If
End Sub

Private Sub graphicshape_DrawQuadraticCurve(ByVal x1 As Integer, _
                                            ByVal y1 As Integer, _
                                            ByVal x2 As Integer, _
                                            ByVal y2 As Integer, _
                                            ByVal x3 As Integer, _
                                            ByVal y3 As Integer, _
                                            ByVal stroke_clr As ULong, _
                                            ByVal line_width As Integer, _
                                            ByVal alpha As Integer)
    Dim i As Integer
    Dim steps As Integer = 32
    Dim t As Double
    Dim inv_t As Double
    Dim px As Integer
    Dim py As Integer
    Dim old_x As Integer
    Dim old_y As Integer

    If line_width <= 0 Or alpha <= 0 Then
        Exit Sub
    End If

    For i = 0 To steps
        t = i / CDbl(steps)
        inv_t = 1.0 - t
        px = CInt((inv_t * inv_t * x1) + _
                  (2.0 * inv_t * t * x2) + _
                  (t * t * x3))
        py = CInt((inv_t * inv_t * y1) + _
                  (2.0 * inv_t * t * y2) + _
                  (t * t * y3))

        If i > 0 Then
            backend_LineEx old_x, old_y, px, py, stroke_clr, line_width, alpha
        End If

        old_x = px
        old_y = py
    Next i
End Sub

Private Sub graphicshape_DrawCubicCurve(ByVal x1 As Integer, _
                                        ByVal y1 As Integer, _
                                        ByVal x2 As Integer, _
                                        ByVal y2 As Integer, _
                                        ByVal x3 As Integer, _
                                        ByVal y3 As Integer, _
                                        ByVal x4 As Integer, _
                                        ByVal y4 As Integer, _
                                        ByVal stroke_clr As ULong, _
                                        ByVal line_width As Integer, _
                                        ByVal alpha As Integer)
    Dim i As Integer
    Dim steps As Integer = 32
    Dim t As Double
    Dim inv_t As Double
    Dim px As Integer
    Dim py As Integer
    Dim old_x As Integer
    Dim old_y As Integer

    If line_width <= 0 Or alpha <= 0 Then
        Exit Sub
    End If

    For i = 0 To steps
        t = i / CDbl(steps)
        inv_t = 1.0 - t
        px = CInt((inv_t * inv_t * inv_t * x1) + _
                  (3.0 * inv_t * inv_t * t * x2) + _
                  (3.0 * inv_t * t * t * x3) + _
                  (t * t * t * x4))
        py = CInt((inv_t * inv_t * inv_t * y1) + _
                  (3.0 * inv_t * inv_t * t * y2) + _
                  (3.0 * inv_t * t * t * y3) + _
                  (t * t * t * y4))

        If i > 0 Then
            backend_LineEx old_x, old_y, px, py, stroke_clr, line_width, alpha
        End If

        old_x = px
        old_y = py
    Next i
End Sub

' -------------------------------------------------------------------------
' Widget API
' -------------------------------------------------------------------------

Sub graphicshape_DefaultOptions(ByRef options As GraphicShapeRenderOptions, _
                                ByVal shape_kind As Integer)
    options.shape_kind = shape_kind
    options.stroke_clr = RGB(0, 0, 0)
    options.fill_clr = RGB(255, 255, 255)
    options.fill_gradient_clr = options.fill_clr
    options.text_clr = options.stroke_clr
    options.filled = 0
    options.fill_mode = GUI_FILL_SOLID
    options.line_width = 1
    options.object_alpha = 255
    options.stroke_alpha = 255
    options.fill_alpha = 255
    options.font_id = BACKEND_FONT_ARIAL_10_REGULAR
    options.text_h_align = BACKEND_ALIGN_LEFT
    options.text_v_align = BACKEND_ALIGN_TOP
    options.text_fit_width = 0
    options.corner_radius = GRAPHICSHAPE_DEFAULT_CORNER_RADIUS
    options.clip_to_bounds = 0
    options.fill_gradient_stop_count = 0
End Sub

Function graphicshape_Create( _
    ByVal nm As String, ByVal shape_kind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal stroke_clr As ULong, ByVal fill_clr As ULong, _
    ByVal filled As Integer, ByVal label As String _
) As Widget Ptr
    Return graphicshape_CreateStyled(nm, shape_kind, x, y, w, h, stroke_clr, _
                                     fill_clr, filled, 1, 255, 255, 255, label)
End Function

Function graphicshape_CreateStyled( _
    ByVal nm As String, ByVal shape_kind As Integer, _
    ByVal x As Integer, ByVal y As Integer, _
    ByVal w As Integer, ByVal h As Integer, _
    ByVal stroke_clr As ULong, ByVal fill_clr As ULong, _
    ByVal filled As Integer, ByVal line_width As Integer, _
    ByVal object_alpha As Integer, ByVal stroke_alpha As Integer, _
    ByVal fill_alpha As Integer, ByVal label As String _
) As Widget Ptr
    Return graphicshape_CreateStyledText(nm, shape_kind, x, y, w, h, _
                                         stroke_clr, fill_clr, filled, _
                                         line_width, object_alpha, _
                                         stroke_alpha, fill_alpha, label, _
                                         BACKEND_FONT_ARIAL_10_REGULAR, _
                                         BACKEND_ALIGN_LEFT, _
                                         BACKEND_ALIGN_TOP)
End Function

Function graphicshape_CreateStyledText( _
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
    Return graphicshape_CreateStyledTextColor(nm, shape_kind, x, y, w, h, _
                                              stroke_clr, fill_clr, stroke_clr, _
                                              filled, line_width, object_alpha, _
                                              stroke_alpha, fill_alpha, label, _
                                              font_id, text_h_align, text_v_align)
End Function

Function graphicshape_CreateStyledTextColor( _
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
    Return graphicshape_CreateStyledTextColorFit(nm, shape_kind, x, y, w, h, _
                                                 stroke_clr, fill_clr, _
                                                 text_clr, filled, _
                                                 line_width, object_alpha, _
                                                 stroke_alpha, fill_alpha, _
                                                 label, font_id, _
                                                 text_h_align, text_v_align, 0)
End Function

Function graphicshape_CreateStyledTextColorFit( _
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
    Dim options As GraphicShapeRenderOptions

    graphicshape_DefaultOptions options, shape_kind
    options.stroke_clr = stroke_clr
    options.fill_clr = fill_clr
    options.fill_gradient_clr = fill_clr
    options.text_clr = text_clr
    options.filled = filled
    options.fill_mode = GUI_FILL_SOLID
    options.line_width = line_width
    options.object_alpha = object_alpha
    options.stroke_alpha = stroke_alpha
    options.fill_alpha = fill_alpha
    options.font_id = font_id
    options.text_h_align = text_h_align
    options.text_v_align = text_v_align
    options.text_fit_width = text_fit_width

    Return graphicshape_CreateWithOptions(nm, x, y, w, h, options, label)
End Function

Function graphicshape_CreateWithOptions(ByVal nm As String, _
                                        ByVal x As Integer, ByVal y As Integer, _
                                        ByVal w As Integer, ByVal h As Integer, _
                                        ByRef options As GraphicShapeRenderOptions, _
                                        ByVal label As String) As Widget Ptr
    Dim As Widget Ptr wgt = New Widget
    Dim As GraphicShapeData Ptr d = New GraphicShapeData
    Dim shape_kind As Integer = options.shape_kind

    graphicshape_NormalizeRenderBox shape_kind, w, h

    wgt->name = nm
    wgt->x = x
    wgt->y = y
    wgt->w = w
    wgt->h = h
    wgt->visible = 1
    wgt->enabled = 1
    wgt->render = @graphicshape_Render
    wgt->destroy = @graphicshape_Destroy

    graphicshape_LoadDataFromOptions *d, options, label
    wgt->data = d
    Return wgt
End Function

Sub graphicshape_RenderWithOptions(ByVal x As Integer, _
                                   ByVal y As Integer, _
                                   ByVal w As Integer, _
                                   ByVal h As Integer, _
                                   ByRef options As GraphicShapeRenderOptions, _
                                   ByVal label As String, _
                                   ByVal point_count As Integer, _
                                   point_x() As Integer, _
                                   point_y() As Integer)
    /'
        Imported screen rendering often draws thousands of one-shot shapes.
        Building a full GUI widget for each primitive creates unnecessary
        allocation churn. This direct path uses the same render data and the
        same graphicshape_Render implementation, but keeps the temporary
        widget on the stack.
    '/

    Dim direct_widget As Widget
    Dim direct_data As GraphicShapeData
    Dim shape_kind As Integer = options.shape_kind
    Dim point_index As Integer

    graphicshape_NormalizeRenderBox shape_kind, w, h
    graphicshape_LoadDataFromOptions direct_data, options, label

    If point_count > GRAPHICSHAPE_MAX_POINTS Then
        point_count = GRAPHICSHAPE_MAX_POINTS
    End If

    If point_count < 0 Then
        point_count = 0
    End If

    direct_data.point_count = point_count

    For point_index = 1 To point_count
        direct_data.point_x(point_index) = point_x(point_index)
        direct_data.point_y(point_index) = point_y(point_index)
    Next point_index

    direct_widget.x = x
    direct_widget.y = y
    direct_widget.ax = x
    direct_widget.ay = y
    direct_widget.w = w
    direct_widget.h = h
    direct_widget.visible = 1
    direct_widget.enabled = 1
    direct_widget.data = @direct_data

    graphicshape_Render @direct_widget
End Sub

Sub graphicshape_SetRenderOptions(ByVal w As Widget Ptr, _
                                  ByRef options As GraphicShapeRenderOptions)
    Dim d As GraphicShapeData Ptr

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    d->shape_kind = options.shape_kind
    d->stroke_clr = options.stroke_clr
    d->fill_clr = options.fill_clr
    d->fill_gradient_clr = options.fill_gradient_clr
    d->text_clr = options.text_clr
    d->filled = options.filled
    d->fill_mode = graphicshape_ClampFillMode(options.fill_mode)
    d->line_width = options.line_width

    If d->line_width < 0 Then
        d->line_width = 0
    End If

    d->object_alpha = graphicshape_ClampAlpha(options.object_alpha)
    d->stroke_alpha = graphicshape_ClampAlpha(options.stroke_alpha)
    d->fill_alpha = graphicshape_ClampAlpha(options.fill_alpha)
    d->font_id = options.font_id
    d->text_h_align = options.text_h_align
    d->text_v_align = options.text_v_align
    d->text_fit_width = options.text_fit_width
    d->corner_radius = options.corner_radius
    d->clip_to_bounds = options.clip_to_bounds
    graphicshape_CopyGradientStops *d, options

    If d->corner_radius < 0 Then
        d->corner_radius = 0
    End If
End Sub

Sub graphicshape_SetCornerRadius(ByVal w As Widget Ptr, _
                                 ByVal corner_radius As Integer)
    Dim d As GraphicShapeData Ptr

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    If corner_radius < 0 Then
        corner_radius = 0
    End If

    d->corner_radius = corner_radius
End Sub

Sub graphicshape_SetClipToBounds(ByVal w As Widget Ptr, _
                                 ByVal clip_to_bounds As Integer)
    Dim d As GraphicShapeData Ptr

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    d->clip_to_bounds = clip_to_bounds
End Sub

Sub graphicshape_SetObjectAlpha(ByVal w As Widget Ptr, _
                                ByVal object_alpha As Integer)
    /'
        Runtime graphic scripts can hide or fade a complete element without
        changing its authored outline or fill style. Object alpha is therefore
        mutable after construction and is combined with the stroke and fill
        alpha values during rendering.
    '/

    Dim d As GraphicShapeData Ptr

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    d->object_alpha = graphicshape_ClampAlpha(object_alpha)
End Sub

Sub graphicshape_SetStrokeAlpha(ByVal w As Widget Ptr, _
                                ByVal stroke_alpha As Integer)
    /'
        The drawing backend uses "stroke" for an object's outline. Keeping the
        setter separate from fill alpha lets visualization code fade an outline
        without changing the object's interior.
    '/

    Dim d As GraphicShapeData Ptr

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    d->stroke_alpha = graphicshape_ClampAlpha(stroke_alpha)
End Sub

Sub graphicshape_SetOutlineAlpha(ByVal w As Widget Ptr, _
                                 ByVal outline_alpha As Integer)
    /'
        Public HMI terminology usually says "outline" or "line style". This is
        a readable alias for the stroke-alpha setter used internally.
    '/

    graphicshape_SetStrokeAlpha w, outline_alpha
End Sub

Sub graphicshape_SetFillAlpha(ByVal w As Widget Ptr, _
                              ByVal fill_alpha As Integer)
    Dim d As GraphicShapeData Ptr

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    d->fill_alpha = graphicshape_ClampAlpha(fill_alpha)
End Sub

Sub graphicshape_SetFillGradient(ByVal w As Widget Ptr, _
                                 ByVal fill_mode As Integer, _
                                 ByVal fill_gradient_clr As ULong)
    /'
        Gradient fill is a drawing option, not a geometry change. Imported
        visualization records and later runtime scripts can switch a shape
        between flat and shaded fill without recreating the widget.
    '/

    Dim d As GraphicShapeData Ptr

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    d->fill_mode = graphicshape_ClampFillMode(fill_mode)
    d->fill_gradient_clr = fill_gradient_clr
End Sub

Sub graphicshape_SetFillGradientStops(ByVal w As Widget Ptr, _
                                      ByVal stop_count As Integer, _
                                      stop_pos() As Integer, _
                                      stop_clr() As ULong)
    /'
        Gradient stops are stored as 0..10000 positions so callers can avoid
        floating point rounding differences. Passing zero stops clears the
        explicit stop list and leaves the simpler fill/gradient-color pair in
        control.
    '/

    Dim d As GraphicShapeData Ptr
    Dim options As GraphicShapeRenderOptions
    Dim stop_index As Integer

    If w = 0 Then
        Exit Sub
    End If

    d = Cast(GraphicShapeData Ptr, w->data)

    If d = 0 Then
        Exit Sub
    End If

    options.fill_gradient_stop_count = stop_count

    If options.fill_gradient_stop_count < 0 Then
        options.fill_gradient_stop_count = 0
    End If

    If options.fill_gradient_stop_count > GRAPHICSHAPE_MAX_GRADIENT_STOPS Then
        options.fill_gradient_stop_count = GRAPHICSHAPE_MAX_GRADIENT_STOPS
    End If

    For stop_index = 1 To options.fill_gradient_stop_count
        options.fill_gradient_stop_pos(stop_index) = stop_pos(stop_index)
        options.fill_gradient_stop_clr(stop_index) = stop_clr(stop_index)
    Next stop_index

    graphicshape_CopyGradientStops *d, options
End Sub

Sub graphicshape_SetPathPoint(ByVal w As Widget Ptr, _
                              ByVal point_index As Integer, _
                              ByVal point_x As Integer, _
                              ByVal point_y As Integer)
    Dim As GraphicShapeData Ptr d

    If w = 0 Then
        Exit Sub
    End If

    d = w->data

    If d = 0 Then
        Exit Sub
    End If

    If point_index < 1 Or point_index > GRAPHICSHAPE_MAX_POINTS Then
        Exit Sub
    End If

    d->point_x(point_index) = point_x
    d->point_y(point_index) = point_y

    If point_index > d->point_count Then
        d->point_count = point_index
    End If
End Sub

Sub graphicshape_Render(ByVal w As Widget Ptr)
    Dim As GraphicShapeData Ptr d = w->data
    Dim As Integer stroke_alpha
    Dim As Integer fill_alpha
    Dim As Integer text_alpha
    Dim As Integer clip_active
    Dim As Integer control_x
    Dim As Integer control_y
    Dim As String display_label

    If d = 0 Then
        Exit Sub
    End If

    If d->object_alpha <= 0 Then
        Exit Sub
    End If

    stroke_alpha = graphicshape_CombineAlpha(d->object_alpha, d->stroke_alpha)
    fill_alpha = graphicshape_CombineAlpha(d->object_alpha, d->fill_alpha)
    text_alpha = graphicshape_ClampAlpha(d->object_alpha)
    clip_active = 0
    control_x = w->ax
    control_y = w->ay
    display_label = graphicshape_SelectedLabel(d)

    If d->clip_to_bounds <> 0 And w->w > 0 And w->h > 0 Then
        /'
            Imported HMI text and controls are normally clipped to their own
            element rectangle. Keeping this optional lets primitive discovery
            tools still draw diagnostic placeholders outside their nominal
            bounds when requested.
        '/

        backend_SetClip w->ax, w->ay, w->w, w->h
        clip_active = 1
    End If

    Select Case d->shape_kind
    Case GUI_SHAPE_LINE, GUI_SHAPE_POLYLINE, GUI_SHAPE_CONNECTOR
        If d->shape_kind = GUI_SHAPE_POLYLINE And d->point_count >= 2 Then
            graphicshape_DrawPath w->ax, w->ay, d->stroke_clr, d->fill_clr, _
                                  0, d->line_width, stroke_alpha, fill_alpha, _
                                  0, d->point_count, d->point_x(), d->point_y()
        Else
            backend_LineEx(w->ax, w->ay, w->ax + w->w, w->ay + w->h, _
                           d->stroke_clr, d->line_width, stroke_alpha)
        End If
    Case GUI_SHAPE_RECTANGLE, GUI_SHAPE_POLYGON
        If d->shape_kind = GUI_SHAPE_POLYGON And d->point_count >= 3 Then
            graphicshape_DrawPath w->ax, w->ay, d->stroke_clr, d->fill_clr, _
                                  d->filled, d->line_width, stroke_alpha, _
                                  fill_alpha, 1, d->point_count, _
                                  d->point_x(), d->point_y()
        Else
            If d->filled <> 0 Then
                graphicshape_FillBox w->ax, w->ay, w->w, w->h, d->fill_clr, _
                                     d->fill_gradient_clr, d->fill_mode, _
                                     d->fill_gradient_stop_count, _
                                     d->fill_gradient_stop_pos(), _
                                     d->fill_gradient_stop_clr(), _
                                     fill_alpha
            End If
            backend_RectEx(w->ax, w->ay, w->w, w->h, d->stroke_clr, 0, _
                           d->line_width, stroke_alpha)
        End If
        If Len(d->label) > 0 And w->w > 18 And w->h > 12 Then
            graphicshape_PrintAlignedMaybeFit w->ax + 3, w->ay + 3, _
                w->w - 6, w->h - 6, d->text_clr, d->label, d->font_id, _
                d->text_h_align, d->text_v_align, d->text_fit_width, _
                text_alpha
        End If
    Case GUI_SHAPE_ROUNDED_RECTANGLE
        graphicshape_DrawRoundRectBox w->ax, w->ay, w->w, w->h, _
                                      d->corner_radius, _
                                      d->stroke_clr, d->fill_clr, _
                                      d->fill_gradient_clr, d->filled, _
                                      d->fill_mode, d->line_width, _
                                      d->fill_gradient_stop_count, _
                                      d->fill_gradient_stop_pos(), _
                                      d->fill_gradient_stop_clr(), _
                                      stroke_alpha, fill_alpha
        If Len(d->label) > 0 And w->w > 18 And w->h > 12 Then
            graphicshape_PrintAlignedMaybeFit w->ax + 3, w->ay + 3, _
                w->w - 6, w->h - 6, d->text_clr, d->label, d->font_id, _
                d->text_h_align, d->text_v_align, d->text_fit_width, _
                text_alpha
        End If
    Case GUI_SHAPE_ELLIPSE
        graphicshape_DrawEllipseBox(w->ax, w->ay, w->w, w->h, d->stroke_clr, _
                                    d->fill_clr, d->filled, d->line_width, _
                                    stroke_alpha, fill_alpha)
    Case GUI_SHAPE_CURVE
        If d->point_count >= 4 Then
            graphicshape_DrawCubicCurve w->ax + d->point_x(1), _
                                        w->ay + d->point_y(1), _
                                        w->ax + d->point_x(2), _
                                        w->ay + d->point_y(2), _
                                        w->ax + d->point_x(3), _
                                        w->ay + d->point_y(3), _
                                        w->ax + d->point_x(4), _
                                        w->ay + d->point_y(4), _
                                        d->stroke_clr, d->line_width, _
                                        stroke_alpha
        ElseIf d->point_count >= 3 Then
            graphicshape_DrawQuadraticCurve w->ax + d->point_x(1), _
                                            w->ay + d->point_y(1), _
                                            w->ax + d->point_x(2), _
                                            w->ay + d->point_y(2), _
                                            w->ax + d->point_x(3), _
                                            w->ay + d->point_y(3), _
                                            d->stroke_clr, d->line_width, _
                                            stroke_alpha
        Else
            graphicshape_DrawQuadraticCurve w->ax, w->ay + w->h, _
                                            w->ax + (w->w \ 2), w->ay, _
                                            w->ax + w->w, w->ay + w->h, _
                                            d->stroke_clr, d->line_width, _
                                            stroke_alpha
        End If
    Case GUI_SHAPE_TEXT
        graphicshape_PrintAlignedMaybeFit w->ax, w->ay, w->w, w->h, _
            d->text_clr, d->label, d->font_id, d->text_h_align, _
            d->text_v_align, d->text_fit_width, text_alpha
    Case GUI_SHAPE_TEXTBOX
        backend_RectEx(w->ax, w->ay, w->w, w->h, d->fill_clr, 1, _
                       d->line_width, fill_alpha)
        backend_RectEx(w->ax, w->ay, w->w, w->h, d->stroke_clr, 0, _
                       d->line_width, stroke_alpha)
        graphicshape_PrintAlignedMaybeFit w->ax + 3, w->ay + 3, _
            w->w - 6, w->h - 6, d->text_clr, d->label, d->font_id, _
            d->text_h_align, d->text_v_align, d->text_fit_width, text_alpha
    Case GUI_SHAPE_BUTTON
        If d->pressed <> 0 Then
            control_x += 1
            control_y += 1
        End If
        backend_RectEx(control_x, control_y, w->w, w->h, d->fill_clr, 1, _
                       d->line_width, fill_alpha)
        backend_RectEx(control_x, control_y, w->w, w->h, d->stroke_clr, 0, _
                       d->line_width, stroke_alpha)
        graphicshape_PrintAlignedMaybeFit control_x + 4, control_y + 2, _
            w->w - 8, w->h - 4, d->text_clr, d->label, d->font_id, _
            d->text_h_align, d->text_v_align, d->text_fit_width, text_alpha
    Case GUI_SHAPE_CHECKBOX
        graphicshape_DrawCheckbox w->ax, w->ay, w->w, w->h, _
                                  d->stroke_clr, d->fill_clr, d->line_width, _
                                  stroke_alpha, fill_alpha, d->label, _
                                  d->font_id, d->value
    Case GUI_SHAPE_COMBOBOX, GUI_SHAPE_DATE_TIME_PICKER
        graphicshape_DrawComboBox w->ax, w->ay, w->w, w->h, _
                                  d->stroke_clr, d->fill_clr, d->line_width, _
                                  stroke_alpha, fill_alpha, display_label, _
                                  d->font_id
    Case GUI_SHAPE_LISTBOX
        graphicshape_DrawListBox w->ax, w->ay, w->w, w->h, _
                                 d->stroke_clr, d->fill_clr, d->line_width, _
                                 stroke_alpha, fill_alpha, d->label, _
                                 d->font_id, d
    Case GUI_SHAPE_EDITBOX
        backend_RectEx(w->ax, w->ay, w->w, w->h, d->fill_clr, 1, _
                       d->line_width, fill_alpha)
        backend_RectEx(w->ax, w->ay, w->w, w->h, d->stroke_clr, 0, _
                       d->line_width, stroke_alpha)
        graphicshape_DrawControlLabel w->ax + 3, w->ay, w->w - 6, w->h, _
                                      d->text_clr, d->label, d->font_id, _
                                      text_alpha
    Case GUI_SHAPE_CALENDAR
        graphicshape_DrawCalendarBox w->ax, w->ay, w->w, w->h, _
                                     d->stroke_clr, d->fill_clr, d->line_width, _
                                     stroke_alpha, fill_alpha, d->value
    Case GUI_SHAPE_RADIO_BUTTON_GROUP
        graphicshape_DrawRadioButtonGroup w->ax, w->ay, w->w, w->h, _
                                          d->stroke_clr, d->fill_clr, _
                                          d->line_width, stroke_alpha, fill_alpha, _
                                          d->label, d->font_id, d->selected_index
    Case GUI_SHAPE_TREND_CONTROL, GUI_SHAPE_TREND_PEN
        graphicshape_DrawTrendBox w->ax, w->ay, w->w, w->h, _
                                  d->stroke_clr, d->fill_clr, d->line_width, _
                                  stroke_alpha, fill_alpha, 0, _
                                  IIf(d->interactive <> 0, d->value, -1)
    Case GUI_SHAPE_MULTI_PEN_TREND
        graphicshape_DrawTrendBox w->ax, w->ay, w->w, w->h, _
                                  d->stroke_clr, d->fill_clr, d->line_width, _
                                  stroke_alpha, fill_alpha, 1, -1
    Case GUI_SHAPE_ALARM_CLIENT
        graphicshape_DrawAlarmClient w->ax, w->ay, w->w, w->h, _
                                     d->stroke_clr, d->fill_clr, d->line_width, _
                                     stroke_alpha, fill_alpha, display_label, _
                                     d->font_id
    Case GUI_SHAPE_ARC
        graphicshape_DrawEllipseBox(w->ax, w->ay, w->w, w->h, d->stroke_clr, _
                                    d->fill_clr, 0, d->line_width, _
                                    stroke_alpha, fill_alpha)
        backend_LineEx(w->ax, w->ay + w->h, w->ax + w->w, w->ay + w->h, _
                       d->stroke_clr, d->line_width, stroke_alpha)
    Case GUI_SHAPE_PIE
        graphicshape_DrawEllipseBox(w->ax, w->ay, w->w, w->h, d->stroke_clr, _
                                    d->fill_clr, d->filled, d->line_width, _
                                    stroke_alpha, fill_alpha)
        backend_LineEx(w->ax + (w->w \ 2), w->ay + (w->h \ 2), _
                       w->ax + w->w, w->ay + (w->h \ 2), d->stroke_clr, _
                       d->line_width, stroke_alpha)
    Case GUI_SHAPE_CHORD
        If Abs(w->h) > Abs(w->w) Then
            graphicshape_DrawVerticalChordBox w->ax, w->ay, w->w, w->h, _
                                             d->stroke_clr, d->fill_clr, _
                                             d->filled, d->line_width, _
                                             stroke_alpha, fill_alpha
        Else
            graphicshape_DrawEllipseBox(w->ax, w->ay, w->w, w->h, d->stroke_clr, _
                                        d->fill_clr, d->filled, d->line_width, _
                                        stroke_alpha, fill_alpha)
            backend_LineEx(w->ax, w->ay + w->h, w->ax + w->w, w->ay + w->h, _
                           d->stroke_clr, d->line_width, stroke_alpha)
        End If
    Case GUI_SHAPE_CONTROL
        If d->interactive <> 0 Then
            display_label = d->label & " " & d->value
        End If
        graphicshape_DrawPlaceholder(w->ax, w->ay, w->w, w->h, d->stroke_clr, _
                                     d->line_width, stroke_alpha, display_label)
    Case GUI_SHAPE_IMAGE, GUI_SHAPE_EMBEDDED_SYMBOL
        graphicshape_DrawPlaceholder(w->ax, w->ay, w->w, w->h, d->stroke_clr, _
                                     d->line_width, stroke_alpha, d->label)
    Case Else
        graphicshape_DrawPlaceholder(w->ax, w->ay, w->w, w->h, d->stroke_clr, _
                                     d->line_width, stroke_alpha, d->label)
    End Select

    If d->interactive <> 0 AndAlso w->has_focus <> 0 AndAlso _
       w->w > 2 AndAlso w->h > 2 Then
        backend_RectEx w->ax + 1, w->ay + 1, w->w - 2, w->h - 2, _
            d->text_clr, 0, 1, text_alpha

        If (d->shape_kind = GUI_SHAPE_TEXTBOX OrElse _
            d->shape_kind = GUI_SHAPE_EDITBOX) AndAlso _
           Int(Timer * 2) Mod 2 = 0 Then
            backend_PrintFontAlpha _
                w->ax + 3 + backend_GetTextWidthFont(d->label, d->font_id), _
                w->ay + ((w->h - backend_GetTextHeightFont(d->font_id)) \ 2), _
                d->text_clr, "|", d->font_id, text_alpha
        End If
    End If

    If clip_active <> 0 Then
        backend_ResetClip
    End If
End Sub

' -------------------------------------------------------------------------
' Optional imported-control interaction
' -------------------------------------------------------------------------

Private Sub graphicshape_ApplyPointerValue( _
    ByVal w As Widget Ptr, ByVal mouse_x As Integer, ByVal mouse_y As Integer _
)
    Dim As Integer choice_count
    Dim As Integer column_index
    Dim As GraphicShapeData Ptr d
    Dim As Integer day_value
    Dim As Integer new_value
    Dim As Integer row_index

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)

    Select Case d->shape_kind
    Case GUI_SHAPE_TEXTBOX, GUI_SHAPE_EDITBOX
        Exit Sub
    Case GUI_SHAPE_CHECKBOX
        d->value = IIf(d->value = 0, -1, 0)
    Case GUI_SHAPE_COMBOBOX, GUI_SHAPE_DATE_TIME_PICKER
        graphicshape_ToggleDropdown w
        Exit Sub
    Case GUI_SHAPE_LISTBOX, GUI_SHAPE_ALARM_CLIENT
        new_value = graphicshape_ChoiceIndexFromPoint(w, d, mouse_y)
        If new_value >= 0 Then graphicshape_ChangeSelection w, new_value
        Exit Sub
    Case GUI_SHAPE_CALENDAR
        If w->w <= 0 OrElse w->h <= 12 Then Exit Sub
        column_index = ((mouse_x - w->ax) * 7) \ w->w
        row_index = ((mouse_y - w->ay - 12) * 5) \ (w->h - 12)
        If column_index < 0 Then column_index = 0
        If column_index > 6 Then column_index = 6
        If row_index < 0 Then row_index = 0
        If row_index > 4 Then row_index = 4
        day_value = (row_index * 7) + column_index + 1
        If day_value > 31 Then day_value = 31
        d->value = day_value
    Case GUI_SHAPE_RADIO_BUTTON_GROUP
        choice_count = d->item_count
        If choice_count <= 0 Then choice_count = 3
        If w->h <= 16 Then Exit Sub
        new_value = ((mouse_y - w->ay - 16) * choice_count) \ (w->h - 16)
        If new_value < 0 Then new_value = 0
        If new_value >= choice_count Then new_value = choice_count - 1

        If d->item_count > 0 Then
            graphicshape_ChangeSelection w, new_value
            Exit Sub
        End If
        d->selected_index = new_value
        d->value = new_value
    Case GUI_SHAPE_CONTROL, GUI_SHAPE_TREND_CONTROL
        If w->w <= 1 Then Exit Sub
        d->value = ((mouse_x - w->ax) * 100) \ (w->w - 1)
        If d->value < 0 Then d->value = 0
        If d->value > 100 Then d->value = 100
    Case Else
        d->value += 1
    End Select

    graphicshape_NotifyChange w
End Sub

Private Sub graphicshape_ApplyWheel( _
    ByVal w As Widget Ptr, ByVal delta_value As Integer _
)
    Dim As GraphicShapeData Ptr d
    Dim As Integer new_value

    If w = 0 OrElse w->data = 0 OrElse delta_value = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)

    Select Case d->shape_kind
    Case GUI_SHAPE_COMBOBOX, GUI_SHAPE_DATE_TIME_PICKER, _
         GUI_SHAPE_LISTBOX, GUI_SHAPE_RADIO_BUTTON_GROUP, _
         GUI_SHAPE_ALARM_CLIENT
        If d->item_count <= 0 Then Exit Sub
        new_value = d->selected_index - delta_value
        graphicshape_ChangeSelection w, new_value
    Case GUI_SHAPE_CALENDAR
        new_value = d->value - delta_value
        If new_value < 1 Then new_value = 1
        If new_value > 31 Then new_value = 31
        If new_value = d->value Then Exit Sub
        d->value = new_value
        graphicshape_NotifyChange w
    Case GUI_SHAPE_CONTROL, GUI_SHAPE_TREND_CONTROL
        new_value = d->value + (delta_value * 5)
        If new_value < 0 Then new_value = 0
        If new_value > 100 Then new_value = 100
        If new_value = d->value Then Exit Sub
        d->value = new_value
        graphicshape_NotifyChange w
    Case Else
        Exit Sub
    End Select
End Sub

Private Sub graphicshape_ApplyKeyboard(ByVal w As Widget Ptr)
    Const GRAPHICSHAPE_KEY_BACKSPACE As Integer = 1
    Const GRAPHICSHAPE_KEY_DOWN As Integer = 2
    Const GRAPHICSHAPE_KEY_RETURN As Integer = 4
    Const GRAPHICSHAPE_KEY_UP As Integer = 8
    Dim As GraphicShapeData Ptr d
    Dim As Integer changed
    Dim As String input_text
    Dim As Integer new_value

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)

    If input_KeyPressed(KEY_BACKSPACE) = 0 Then
        d->key_latch And= Not GRAPHICSHAPE_KEY_BACKSPACE
    End If
    If input_KeyPressed(KEY_DOWN) = 0 Then
        d->key_latch And= Not GRAPHICSHAPE_KEY_DOWN
    End If
    If input_KeyPressed(KEY_RETURN) = 0 Then
        d->key_latch And= Not GRAPHICSHAPE_KEY_RETURN
    End If
    If input_KeyPressed(KEY_UP) = 0 Then
        d->key_latch And= Not GRAPHICSHAPE_KEY_UP
    End If

    If d->shape_kind = GUI_SHAPE_TEXTBOX OrElse _
       d->shape_kind = GUI_SHAPE_EDITBOX Then
        input_text = input_PollTextInput()
        If input_text <> "" AndAlso _
           Len(d->label) < GRAPHICSHAPE_MAX_INPUT_LENGTH Then
            d->label &= Left( _
                input_text, GRAPHICSHAPE_MAX_INPUT_LENGTH - Len(d->label) _
            )
            changed = -1
        End If

        If input_KeyPressed(KEY_BACKSPACE) <> 0 AndAlso _
           (d->key_latch And GRAPHICSHAPE_KEY_BACKSPACE) = 0 Then
            d->key_latch Or= GRAPHICSHAPE_KEY_BACKSPACE
            If Len(d->label) > 0 Then
                d->label = Left(d->label, Len(d->label) - 1)
                changed = -1
            End If
        End If

        If changed <> 0 Then graphicshape_NotifyChange w
        Exit Sub
    End If

    If input_KeyPressed(KEY_RETURN) <> 0 AndAlso _
       (d->key_latch And GRAPHICSHAPE_KEY_RETURN) = 0 Then
        d->key_latch Or= GRAPHICSHAPE_KEY_RETURN

        If d->shape_kind = GUI_SHAPE_BUTTON Then
            graphicshape_NotifyChange w
        ElseIf d->shape_kind = GUI_SHAPE_CHECKBOX Then
            d->value = IIf(d->value = 0, -1, 0)
            graphicshape_NotifyChange w
        ElseIf d->shape_kind = GUI_SHAPE_COMBOBOX OrElse _
               d->shape_kind = GUI_SHAPE_DATE_TIME_PICKER Then
            graphicshape_ToggleDropdown w
        End If
    End If

    If d->item_count <= 0 Then Exit Sub
    new_value = d->selected_index

    If input_KeyPressed(KEY_UP) <> 0 AndAlso _
       (d->key_latch And GRAPHICSHAPE_KEY_UP) = 0 Then
        d->key_latch Or= GRAPHICSHAPE_KEY_UP
        new_value -= 1
    ElseIf input_KeyPressed(KEY_DOWN) <> 0 AndAlso _
           (d->key_latch And GRAPHICSHAPE_KEY_DOWN) = 0 Then
        d->key_latch Or= GRAPHICSHAPE_KEY_DOWN
        new_value += 1
    End If

    graphicshape_ChangeSelection w, new_value
End Sub

Sub graphicshape_Update(ByVal w As Widget Ptr)
    Dim As GraphicShapeData Ptr d
    Dim As Integer inside
    Dim As Integer mouse_buttons
    Dim As Integer mouse_x
    Dim As Integer mouse_y

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)
    If d->interactive = 0 Then Exit Sub

    If d->dropdown_widget <> 0 AndAlso _
       d->dropdown_widget->visible <> 0 AndAlso _
       gui_GetFocus() <> w AndAlso _
       gui_GetFocus() <> d->dropdown_widget Then
        graphicshape_CloseDropdown w
    End If

    mouse_x = input_MouseX()
    mouse_y = input_MouseY()
    mouse_buttons = input_MouseButtons() And 1
    inside = graphicshape_PointInside(w, mouse_x, mouse_y)

    If d->shape_kind = GUI_SHAPE_BUTTON Then
        If mouse_buttons <> 0 Then
            If inside <> 0 Then
                d->pressed = -1
                d->pointer_latch = -1
            Else
                d->pressed = 0
            End If
        Else
            If d->pointer_latch <> 0 AndAlso d->pressed <> 0 AndAlso _
               inside <> 0 Then
                graphicshape_NotifyChange w
            End If
            d->pressed = 0
            d->pointer_latch = 0
        End If
    ElseIf mouse_buttons <> 0 Then
        If inside <> 0 AndAlso d->pointer_latch = 0 Then
            d->pointer_latch = -1
            graphicshape_ApplyPointerValue w, mouse_x, mouse_y
        End If
    Else
        d->pointer_latch = 0
    End If

    If inside <> 0 Then graphicshape_ApplyWheel w, input_MouseWheel()
    graphicshape_ApplyKeyboard w
End Sub

Sub graphicshape_SetInteractive( _
    ByVal w As Widget Ptr, ByVal enabled As Integer, _
    ByVal change_handler As Any Ptr _
)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)
    d->interactive = IIf(enabled <> 0, -1, 0)
    d->change_handler = change_handler
    d->pressed = 0
    d->pointer_latch = 0
    d->key_latch = 0

    If d->interactive <> 0 Then
        w->update = @graphicshape_Update
        w->accepts_focus = -1
    Else
        graphicshape_CloseDropdown w
        w->update = 0
        w->accepts_focus = 0
        If gui_GetFocus() = w Then gui_SetFocus 0
    End If
End Sub

Function graphicshape_IsInteractive(ByVal w As Widget Ptr) As Integer
    If w = 0 OrElse w->data = 0 Then Return 0
    Return Cast(GraphicShapeData Ptr, w->data)->interactive
End Function

Sub graphicshape_SetValue(ByVal w As Widget Ptr, ByVal value As Integer)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)

    Select Case d->shape_kind
    Case GUI_SHAPE_CHECKBOX
        d->value = IIf(value <> 0, -1, 0)
    Case GUI_SHAPE_CALENDAR
        If value < 1 Then value = 1
        If value > 31 Then value = 31
        d->value = value
    Case GUI_SHAPE_CONTROL, GUI_SHAPE_TREND_CONTROL
        If value < 0 Then value = 0
        If value > 100 Then value = 100
        d->value = value
    Case Else
        d->value = value
    End Select

    If d->item_count > 0 Then
        If d->value < 0 Then d->value = 0
        If d->value >= d->item_count Then d->value = d->item_count - 1
        d->selected_index = d->value
    End If
End Sub

Function graphicshape_GetValue(ByVal w As Widget Ptr) As Integer
    If w = 0 OrElse w->data = 0 Then Return 0
    Return Cast(GraphicShapeData Ptr, w->data)->value
End Function

Sub graphicshape_SetText(ByVal w As Widget Ptr, ByVal text As String)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)
    d->label = Left(text, GRAPHICSHAPE_MAX_INPUT_LENGTH)
End Sub

Function graphicshape_GetText(ByVal w As Widget Ptr) As String
    If w = 0 OrElse w->data = 0 Then Return ""
    Return Cast(GraphicShapeData Ptr, w->data)->label
End Function

Sub graphicshape_ClearItems(ByVal w As Widget Ptr)
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Exit Sub
    d = Cast(GraphicShapeData Ptr, w->data)

    For item_index As Integer = 0 To GRAPHICSHAPE_MAX_ITEMS - 1
        d->items(item_index) = ""
    Next item_index

    d->item_count = 0
    d->selected_index = -1
    d->value = 0
    graphicshape_CloseDropdown w
End Sub

Function graphicshape_AddItem( _
    ByVal w As Widget Ptr, ByVal item_text As String _
) As Integer
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Return 0
    d = Cast(GraphicShapeData Ptr, w->data)
    If d->item_count >= GRAPHICSHAPE_MAX_ITEMS Then Return 0

    d->items(d->item_count) = item_text
    d->item_count += 1

    If d->selected_index < 0 Then
        d->selected_index = 0
        d->value = 0
    End If

    graphicshape_CloseDropdown w

    Return -1
End Function

Function graphicshape_GetSelectedIndex(ByVal w As Widget Ptr) As Integer
    If w = 0 OrElse w->data = 0 Then Return -1
    Return Cast(GraphicShapeData Ptr, w->data)->selected_index
End Function

Function graphicshape_GetSelectedItem(ByVal w As Widget Ptr) As String
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Return ""
    d = Cast(GraphicShapeData Ptr, w->data)
    If d->selected_index < 0 OrElse _
       d->selected_index >= d->item_count Then
        Return ""
    End If

    Return d->items(d->selected_index)
End Function

Function graphicshape_GetChangeCount(ByVal w As Widget Ptr) As Integer
    If w = 0 OrElse w->data = 0 Then Return 0
    Return Cast(GraphicShapeData Ptr, w->data)->change_count
End Function

Function graphicshape_IsDropdownOpen(ByVal w As Widget Ptr) As Integer
    Dim As GraphicShapeData Ptr d

    If w = 0 OrElse w->data = 0 Then Return 0
    d = Cast(GraphicShapeData Ptr, w->data)
    If d->dropdown_widget = 0 Then Return 0
    Return IIf(d->dropdown_widget->visible <> 0, -1, 0)
End Function

Sub graphicshape_Destroy(ByVal w As Widget Ptr)
    Delete Cast(GraphicShapeData Ptr, w->data)
End Sub

/' end of graphicshape.bas '/

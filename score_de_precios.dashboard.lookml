---
- dashboard: comercial_slide_4_score_de_precios
  title: COMERCIAL_SLIDE_4_SCORE_DE_PRECIOS
  preferred_viewer: dashboards-next
  description: ''
  preferred_slug: cfiE3kpmlDSe2bkYVTyGKe
  layout: newspaper
  tabs:
  - name: ''
    label: ''
  elements:
  - title: Untitled
    name: Untitled
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_superior
    type: looker_grid
    fields: [cuadrante_izquierdo_superior.pais, cuadrante_izquierdo_superior.producto_tipo,
      cuadrante_izquierdo_superior.semana, cuadrante_izquierdo_superior.referencia_nombre,
      cuadrante_izquierdo_superior.precio_usd, cuadrante_izquierdo_superior.precio_nov,
      cuadrante_izquierdo_superior.precio_caida_mxn, cuadrante_izquierdo_superior.caida_porcentual,
      cuadrante_izquierdo_superior.senal_porcentual, cuadrante_izquierdo_superior.indice_precio]
    sorts: [cuadrante_izquierdo_superior.precio_usd desc 0]
    limit: 500
    column_limit: 50
    show_view_names: false
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    limit_displayed_rows: false
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    hidden_pivots: {}
    listen: {}
    row: 0
    col: 0
    width: 8
    height: 7
    tab_name: ''
  - title: Untitled
    name: Untitled (2)
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_superior
    type: looker_column
    fields: [cuadrante_izquierdo_superior.semana, cuadrante_izquierdo_superior.precio_caida_mxn,
      cuadrante_izquierdo_superior.precio_nov, cuadrante_izquierdo_superior.precio_pulso_min]
    sorts: [cuadrante_izquierdo_superior.precio_caida_mxn desc 0]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_series: []
    series_colors:
      cuadrante_izquierdo_superior.precio_pulso_min: "#F9AB00"
    defaults_version: 1
    listen: {}
    row: 0
    col: 8
    width: 7
    height: 7
    tab_name: ''
  - title: Untitled
    name: Untitled (3)
    model: ven_mart_comercial_model_test
    explore: cuadrante_superior_derecha
    type: looker_scatter
    fields: [cuadrante_superior_derecha.spread, cuadrante_superior_derecha.toneladas_facturadas,
      cuadrante_superior_derecha.semana_label, cuadrante_superior_derecha.indice_precio]
    sorts: [cuadrante_superior_derecha.spread desc 0]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: circle
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    show_null_points: true
    y_axes: [{label: '', orientation: left, series: [{axisId: cuadrante_superior_derecha.spread,
            id: cuadrante_superior_derecha.spread, name: Spread}, {axisId: cuadrante_superior_derecha.toneladas_facturadas,
            id: cuadrante_superior_derecha.toneladas_facturadas, name: Toneladas Facturadas}],
        showLabels: true, showValues: true, unpinAxis: false, tickDensity: default,
        tickDensityCustom: 5, type: linear}]
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_series: [cuadrante_superior_derecha.spread]
    series_colors:
      cuadrante_superior_derecha.toneladas_facturadas: "#FF6B00"
      cuadrante_superior_derecha.spread: "#237a16"
    cluster_points: false
    quadrants_enabled: false
    quadrant_properties:
      '0':
        color: ''
        label: Quadrant 1
      '1':
        color: ''
        label: Quadrant 2
      '2':
        color: ''
        label: Quadrant 3
      '3':
        color: ''
        label: Quadrant 4
    custom_quadrant_point_x: 5
    custom_quadrant_point_y: 5
    custom_x_column: ''
    custom_y_column: ''
    custom_value_label_column: ''
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    hidden_fields: [cuadrante_superior_derecha.indice_precio, cuadrante_superior_derecha.spread]
    hidden_pivots: {}
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    interpolation: linear
    value_labels: legend
    label_type: labPer
    listen: {}
    row: 0
    col: 15
    width: 9
    height: 7
    tab_name: ''
  - title: Untitled
    name: Untitled (4)
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_inferior
    type: looker_column
    fields: [cuadrante_izquierdo_inferior.semana, cuadrante_izquierdo_inferior.precio_caida_promedio,
      cuadrante_izquierdo_inferior.platts_promedio, cuadrante_izquierdo_inferior.senal_precio_promedio,
      cuadrante_izquierdo_inferior.precio_importacion_promedio, cuadrante_izquierdo_inferior.precio_opvo_calculado,
      cuadrante_izquierdo_inferior.toneladas_pvo_total, cuadrante_izquierdo_inferior.toneladas_facturadas_total]
    sorts: [cuadrante_izquierdo_inferior.precio_caida_promedio desc]
    limit: 500
    column_limit: 50
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    x_axis_zoom: true
    y_axis_zoom: true
    hidden_series: []
    series_colors:
      cuadrante_izquierdo_inferior.senal_precio_promedio: "#2da3c7"
    advanced_vis_config: |-
      {
        "chart": {},
        "plotOptions": {
          "line": {
            "dataLabels": { "enabled": false }
          },
          "column": {
            "dataLabels": { "enabled": true }
          }
        },
        "series": [
          { "name": "Precio Caida Promedio", "type": "line", "yAxis": 0 },
          { "name": "Platts Promedio", "type": "line", "yAxis": 0 },
          { "name": "Senal Precio Promedio", "type": "line", "yAxis": 0 },
          { "name": "Precio Importacion Promedio", "type": "line", "yAxis": 0 },
          { "name": "Precio Opvo Calculado", "type": "line", "yAxis": 0 },
          { "name": "Toneladas Pvo Total", "type": "column", "yAxis": 1 },
          { "name": "Toneladas Facturadas Total", "type": "column", "yAxis": 1 }
        ],
        "yAxis": [
          { "title": { "text": "Precio (MXN)" }, "labels": { "format": "${value:,.0f}" } },
          { "title": { "text": "Toneladas" }, "opposite": true, "min": 0 }
        ]
      }
    defaults_version: 1
    show_null_points: true
    interpolation: linear
    listen: {}
    row: 15
    col: 0
    width: 15
    height: 6
    tab_name: ''
  - title: ''
    name: Untitled (5)
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_inferior
    type: looker_donut_multiples
    fields: [cuadrante_izquierdo_inferior.semana, cuadrante_izquierdo_inferior.senal_precio_promedio,
      cuadrante_izquierdo_inferior.precio_minimo_historico, cuadrante_izquierdo_inferior.precio_maximo_historico]
    sorts: [cuadrante_izquierdo_inferior.senal_precio_promedio desc 0]
    limit: 500
    column_limit: 50
    show_value_labels: false
    font_size: 12
    series_colors:
      cuadrante_izquierdo_inferior.precio_maximo_historico: "#F9AB00"
    series_labels: {}
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    value_labels: legend
    label_type: labPer
    hidden_fields: []
    hidden_points_if_no: []
    bin_type: bins
    bin_style: simple_hist
    winsorization: false
    color_col: "#1A73E8"
    color_on_hover: "#338bff"
    x_axis_override: ''
    x_grids: true
    x_axis_title_font_size: 16
    x_axis_label_font_size: 12
    x_axis_label_angle: 0
    x_label_separation: 100
    y_axis_override: ''
    y_grids: true
    y_axis_title_font_size: 16
    y_axis_label_font_size: 12
    y_axis_label_angle: 0
    y_label_separation: 100
    x_axis_value_format: ''
    leftAxisLabelVisible: false
    leftAxisLabel: ''
    rightAxisLabelVisible: false
    rightAxisLabel: ''
    smoothedBars: false
    orientation: automatic
    labelPosition: left
    percentType: total
    percentPosition: inline
    valuePosition: right
    labelColorEnabled: false
    labelColor: "#FFF"
    hidden_pivots: {}
    color_application: undefined
    up_color: false
    down_color: false
    total_color: false
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    show_null_points: true
    interpolation: linear
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    show_variance: true
    variance_format: percentage
    comparison_label: Vs periodo anterior
    color_scheme: primary
    icon: ''
    animate: true
    invert_colors: false
    compact_numbers: false
    map: usa
    map_projection: ''
    quantize_colors: false
    listen: {}
    row: 7
    col: 0
    width: 9
    height: 8
    tab_name: ''
  - title: Limite Superior
    name: Limite Superior
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_inferior
    type: single_value
    fields: [cuadrante_izquierdo_inferior.semana, cuadrante_izquierdo_inferior.limite_superior]
    sorts: [cuadrante_izquierdo_inferior.limite_superior desc 0]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    hidden_pivots: {}
    listen: {}
    row: 7
    col: 9
    width: 6
    height: 2
    tab_name: ''
  - title: Limite Inferior
    name: Limite Inferior
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_inferior
    type: single_value
    fields: [cuadrante_izquierdo_inferior.semana, cuadrante_izquierdo_inferior.limite_inferior]
    sorts: [cuadrante_izquierdo_inferior.limite_inferior desc 0]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    listen: {}
    row: 11
    col: 9
    width: 6
    height: 2
    tab_name: ''
  - title: Precio Caida Sem Anterior
    name: Precio Caida Sem Anterior
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_inferior
    type: single_value
    fields: [cuadrante_izquierdo_inferior.semana, cuadrante_izquierdo_inferior.precio_semana_anterior]
    sorts: [cuadrante_izquierdo_inferior.precio_semana_anterior desc 0]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    hidden_pivots: {}
    listen: {}
    row: 13
    col: 9
    width: 6
    height: 2
    tab_name: ''
  - title: Untitled
    name: Untitled (6)
    model: ven_mart_comercial_model_test
    explore: cuadrante_derecho_inferior
    type: looker_grid
    fields: [cuadrante_derecho_inferior.nombre_periodo_mostrar, cuadrante_derecho_inferior.precio_varilla,
      cuadrante_derecho_inferior.costo_mezcla, cuadrante_derecho_inferior.spread,
      cuadrante_derecho_inferior.costo_mezcla_variacion_pct, cuadrante_derecho_inferior.spread_variacion_pct]
    sorts: [cuadrante_derecho_inferior.precio_varilla desc 0]
    limit: 500
    column_limit: 50
    show_view_names: false
    show_row_numbers: true
    transpose: false
    truncate_text: true
    hide_totals: false
    hide_row_totals: false
    size_to_fit: true
    table_theme: white
    limit_displayed_rows: false
    enable_conditional_formatting: false
    header_text_alignment: left
    header_font_size: 12
    rows_font_size: 12
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    defaults_version: 1
    listen: {}
    row: 7
    col: 15
    width: 9
    height: 14
    tab_name: ''
  - title: Prediccion
    name: Prediccion
    model: ven_mart_comercial_model_test
    explore: cuadrante_izquierdo_inferior
    type: single_value
    fields: [cuadrante_izquierdo_inferior.semana, cuadrante_izquierdo_inferior.precio_caida_promedio]
    sorts: [cuadrante_izquierdo_inferior.precio_caida_promedio desc 0]
    limit: 500
    column_limit: 50
    custom_color_enabled: true
    show_single_value_title: true
    show_comparison: false
    comparison_type: value
    comparison_reverse_colors: false
    show_comparison_label: true
    enable_conditional_formatting: false
    conditional_formatting_include_totals: false
    conditional_formatting_include_nulls: false
    x_axis_gridlines: false
    y_axis_gridlines: true
    show_view_names: false
    show_y_axis_labels: true
    show_y_axis_ticks: true
    y_axis_tick_density: default
    y_axis_tick_density_custom: 5
    show_x_axis_label: true
    show_x_axis_ticks: true
    y_axis_scale_mode: linear
    x_axis_reversed: false
    y_axis_reversed: false
    plot_size_by_field: false
    trellis: ''
    stacking: ''
    limit_displayed_rows: false
    legend_position: center
    point_style: none
    show_value_labels: false
    label_density: 25
    x_axis_scale: auto
    y_axis_combined: true
    ordering: none
    show_null_labels: false
    show_totals_labels: false
    show_silhouette: false
    totals_color: "#808080"
    defaults_version: 1
    listen: {}
    row: 9
    col: 9
    width: 6
    height: 2
    tab_name: ''
  filters:
  - name: Nom Grupo Estadistico1
    title: Nom Grupo Estadistico1
    type: field_filter
    default_value: VARILLA
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: ven_mart_comercial_model_test
    explore: ven_mart_comercial
    listens_to_filters: []
    field: ven_mart_comercial.nom_grupo_estadistico1
  - name: Nom Grupo Estadistico2
    title: Nom Grupo Estadistico2
    type: field_filter
    default_value: 2D&3D
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: ven_mart_comercial_model_test
    explore: ven_mart_comercial
    listens_to_filters: []
    field: ven_mart_comercial.nom_grupo_estadistico2
  - name: Nom Grupo Estadistico3
    title: Nom Grupo Estadistico3
    type: field_filter
    default_value: "^ 8X19-26 AA GALV QUERETARO"
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: ven_mart_comercial_model_test
    explore: ven_mart_comercial
    listens_to_filters: []
    field: ven_mart_comercial.nom_grupo_estadistico3
  - name: Nom Grupo Estadistico4
    title: Nom Grupo Estadistico4
    type: field_filter
    default_value: '" 2-3 1/8\"8X31-41 AA NEG QRO."'
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: ven_mart_comercial_model_test
    explore: ven_mart_comercial
    listens_to_filters: []
    field: ven_mart_comercial.nom_grupo_estadistico4
  - name: Nom Subdireccion
    title: Nom Subdireccion
    type: field_filter
    default_value: AGRICULTURAL DISTRIBUTION
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: ven_mart_comercial_model_test
    explore: ven_mart_comercial
    listens_to_filters: []
    field: ven_mart_comercial.nom_subdireccion
  - name: Nom Gerencia
    title: Nom Gerencia
    type: field_filter
    default_value: 2D & 3D
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: ven_mart_comercial_model_test
    explore: ven_mart_comercial
    listens_to_filters: []
    field: ven_mart_comercial.nom_gerencia
  - name: Nom Zona
    title: Nom Zona
    type: field_filter
    default_value: "^ INGETEK SOLUCIONES - TALUDES"
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: ven_mart_comercial_model_test
    explore: ven_mart_comercial
    listens_to_filters: []
    field: ven_mart_comercial.nom_zona

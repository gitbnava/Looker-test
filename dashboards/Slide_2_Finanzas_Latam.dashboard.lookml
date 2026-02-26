---
- dashboard: facturacion_latam
  title: Facturacion_LATAM
  preferred_viewer: dashboards-next
  description: ''
  preferred_slug: C38iQpZNMY4yHJBDHHTAFu
  layout: newspaper
  tabs:
  - name: ''
    label: ''
  elements:
  - title: ''
    name: ''
    model: finanzas_latam
    explore: tablero_direccion_gii
    type: marketplace_viz_report_table::report_table-marketplace
    fields: [tablero_direccion_gii.nom_direccion, tablero_direccion_gii.gii, tablero_direccion_gii.pedidos_ton,
      tablero_direccion_gii.deuda_pm, tablero_direccion_gii.deuda_total, tablero_direccion_gii.deuda_libre,
      tablero_direccion_gii.deuda_autofleteo, tablero_direccion_gii.deuda_mes_resto,
      tablero_direccion_gii.deuda_mes_siguiente, tablero_direccion_gii.fact_ayer,
      tablero_direccion_gii.fact_acum, tablero_direccion_gii.fact_pm, tablero_direccion_gii.pvo,
      tablero_direccion_gii.pct_pvo, tablero_direccion_gii.bp, tablero_direccion_gii.pct_bp,
      tablero_direccion_gii.fact_acum_2023, tablero_direccion_gii.fact_acum_2024,
      tablero_direccion_gii.fact_acum_2025]
    sorts: [tablero_direccion_gii.pedidos_ton desc 0]
    limit: 500
    column_limit: 50
    hidden_fields: []
    hidden_points_if_no: []
    series_labels: {}
    show_view_names: false
    hidden_pivots: {}
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
    defaults_version: 0
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
    theme: traditional
    customTheme: ''
    layout: fixed
    minWidthForIndexColumns: true
    headerFontSize: 12
    bodyFontSize: 12
    showTooltip: true
    showHighlight: true
    rowSubtotals: false
    colSubtotals: false
    spanRows: true
    spanCols: true
    calculateOthers: true
    sortColumnsBy: pivots
    useViewName: false
    useHeadings: false
    useShortName: false
    useUnit: false
    groupVarianceColumns: false
    genericLabelForSubtotals: false
    indexColumn: false
    transposeTable: false
    columnOrder: {}
    listen:
      Nom Grupo Estadistico4: tablero_direccion_gii.nom_grupo_estadistico4
      Nom Grupo Estadistico2: tablero_direccion_gii.nom_grupo_estadistico2
      Nom Grupo Estadistico3: tablero_direccion_gii.nom_grupo_estadistico3
      Nom Grupo Estadistico1: tablero_direccion_gii.nom_grupo_estadistico1
      Nom Estado: tablero_direccion_gii.nom_estado
      Nom Subdireccion: tablero_direccion_gii.nom_subdireccion
      Nom Zona: tablero_direccion_gii.nom_zona
      Nom Direccion: tablero_direccion_gii.nom_direccion
      Nom Cliente: tablero_direccion_gii.nom_cliente
      Nombre Periodo Mostrar: tablero_direccion_gii.nombre_periodo_mostrar
    row: 0
    col: 0
    width: 24
    height: 27
    tab_name: ''
  filters:
  - name: Nom Direccion
    title: Nom Direccion
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_direccion
  - name: Nom Grupo Estadistico1
    title: Nom Grupo Estadistico1
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_grupo_estadistico1
  - name: Nom Grupo Estadistico2
    title: Nom Grupo Estadistico2
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_grupo_estadistico2
  - name: Nom Grupo Estadistico3
    title: Nom Grupo Estadistico3
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_grupo_estadistico3
  - name: Nom Grupo Estadistico4
    title: Nom Grupo Estadistico4
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_grupo_estadistico4
  - name: Nom Cliente
    title: Nom Cliente
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_cliente
  - name: Nom Subdireccion
    title: Nom Subdireccion
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_subdireccion
  - name: Nom Zona
    title: Nom Zona
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_zona
  - name: Nom Estado
    title: Nom Estado
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nom_estado
  - name: Nombre Periodo Mostrar
    title: Nombre Periodo Mostrar
    type: field_filter
    default_value: ''
    allow_multiple_values: true
    required: false
    ui_config:
      type: dropdown_menu
      display: inline
    model: finanzas_latam
    explore: tablero_direccion_gii
    listens_to_filters: []
    field: tablero_direccion_gii.nombre_periodo_mostrar

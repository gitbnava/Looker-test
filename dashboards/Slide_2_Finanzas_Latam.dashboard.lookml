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
  - title: Finanzas Latam
    name: Finanzas Latam
    model: finanzas_latam
    explore: tablero_direccion_gii_v2
    type: wc_price_analysis_prod::deacero-tree-table
    fields: [tablero_direccion_gii_v2.nom_direccion, tablero_direccion_gii_v2.nom_subdireccion,
      tablero_direccion_gii_v2.nom_gerencia, tablero_direccion_gii_v2.nom_grupo_estadistico1,
      tablero_direccion_gii_v2.nom_grupo_estadistico2, tablero_direccion_gii_v2.nom_grupo_estadistico3,
      tablero_direccion_gii_v2.pedidos_ton, tablero_direccion_gii_v2.precio_deuda_total,
      tablero_direccion_gii_v2.deuda_total, tablero_direccion_gii_v2.deuda_libre,
      tablero_direccion_gii_v2.deuda_autofleteo, tablero_direccion_gii_v2.deuda_mes_resto,
      tablero_direccion_gii_v2.deuda_mes_siguiente, tablero_direccion_gii_v2.fact_ayer,
      tablero_direccion_gii_v2.fact_acum, tablero_direccion_gii_v2.fact_acum_importe,
      tablero_direccion_gii_v2.precio_destino_mn, tablero_direccion_gii_v2.pvo, tablero_direccion_gii_v2.pct_pvo,
      tablero_direccion_gii_v2.bp, tablero_direccion_gii_v2.pct_bp, tablero_direccion_gii_v2.fact_acum_2026,
      tablero_direccion_gii_v2.fact_acum_2025]
    sorts: [tablero_direccion_gii_v2.pedidos_ton desc 0]
    limit: 500
    column_limit: 50
    hidden_fields: []
    hidden_points_if_no: []
    series_labels: {}
    show_view_names: false
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
    defaultExpandDepth: 1
    showSubtotals: true
    showGrandTotal: true
    showRowCounts: true
    indentSize: 20
    respectLookmlFormat: true
    numberDecimals: 2
    headerBackground: "#f5f5f5"
    groupRowBackground: "#fafafa"
    fontSize: '12'
    rowStriping: true
    aggModeField: ''
    aggWeightField: ''
    color_total: "#1A73E8"
    color_cargo: "#34A853"
    color_descuento: "#EA4335"
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
    signal_enabled: false
    tile_title: ''
    auto_hide_empty: true
    agg_type__tablero_direccion_gii_v2_pedidos_ton: sum
    agg_weight__tablero_direccion_gii_v2_pedidos_ton: ''
    listen: {}
    row: 0
    col: 0
    width: 24
    height: 28
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

# =====================================================
# Tablero por Dirección y GII (Grupo de inventario) — Facturación LATAM
# Dashboard: tabla por Dirección (nom_direccion) y GII con métricas
# de pedidos, deuda, facturación, ventas (PVO/BP), histórico y mercado.
# Incluye filtros y drill-down jerárquico: Dirección → Subdirección → Gerencia
# y GII (GE1) → GE2 → GE3 → GE4.
# Fuente: ven_mart_comercial
# =====================================================

view: tablero_direccion_gii {
  derived_table: {
    sql:
      SELECT
        v.nom_direccion,
        v.nom_grupo_estadistico1 AS gii,
        v.nom_grupo_estadistico1,
        v.nom_grupo_estadistico2,
        v.nom_grupo_estadistico3,
        v.nom_grupo_estadistico4,
        v.nom_subdireccion,
        v.nom_gerencia,
        v.nom_zona,
        v.nom_cliente_unico AS nom_cliente,
        v.nom_zona AS zona,
        v.nom_estado_consignado AS nom_estado,
        v.nom_canal,
        v.control,
        v.anio,
        v.anio_mes AS mes,
        v.anio_semana AS semana,
        v.nombre_periodo_mostrar,
        v.fecha AS fecha_contable,
        v.toneladas_pedidas,
        v.toneladas_deuda_total,
        v.toneladas_deuda_libre,
        v.toneladas_deuda_auto_fleteo AS deuda_autofleteo,
        v.toneladas_deuda_mes_resto,
        v.toneladas_deuda_mes_siguiente,
        v.toneladas_facturadas,
        v.imp_precio_entrega_mn AS imp_facturacion_mn,
        v.toneladas_pvo,
        v.toneladas_business_plan,
        -- Bloque MERCADO (columnas nativas del mart)
        v.edm_total,
        v.edm_distribuido,
        v.vnp_total,
        v.vnp_distribuido,
        v.inercial_cna,
        v.inercial_cna_distribuido,
        v.inercial_total_tons_facturadas,
        v.inercial_total_tons_bs,
        v.promedio_cna_anio_actual,
        v.toneladas_inerciales
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
      WHERE v.nom_direccion IS NOT NULL
        AND v.nom_grupo_estadistico1 IS NOT NULL
        AND v.nom_grupo_estadistico1 != ''
        AND v.anio IS NOT NULL
        AND v.fecha IS NOT NULL
        AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 48 MONTH)
        AND v.fecha <= DATE_ADD(CURRENT_DATE(), INTERVAL 12 MONTH)
        AND (v.anio_mes IS NOT NULL OR v.anio_semana IS NOT NULL)
    ;;
  }

  # ============================================
  # DIMENSIONES DE FILA (Dirección, GII, drill-down)
  # ============================================

  dimension: nom_direccion {
    type: string
    sql: ${TABLE}.nom_direccion ;;
    description: "Dirección (ej. ACEROS MEXICO, EXPORTACION LATAM). Drill-down hasta gerencia."
  }

  dimension: gii {
    type: string
    sql: ${TABLE}.gii ;;
    description: "Grupo de inventario / categoría producto (GII). Drill-down hasta grupo estadístico 4."
  }

  dimension: nom_grupo_estadistico1 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico1 ;;
    description: "Gpo. Estadístico 1"
  }

  dimension: nom_grupo_estadistico2 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico2 ;;
    description: "Gpo. Estadístico 2"
  }

  dimension: nom_grupo_estadistico3 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico3 ;;
    description: "Gpo. Estadístico 3"
  }

  dimension: nom_grupo_estadistico4 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico4 ;;
    description: "Gpo. Estadístico 4"
  }

  dimension: nom_subdireccion {
    type: string
    sql: ${TABLE}.nom_subdireccion ;;
    description: "Subdirección"
  }

  dimension: nom_gerencia {
    type: string
    sql: ${TABLE}.nom_gerencia ;;
    description: "Gerencias"
  }

  dimension: nom_zona {
    type: string
    sql: ${TABLE}.nom_zona ;;
    description: "Zona"
  }

  dimension: zona {
    type: string
    sql: ${TABLE}.zona ;;
    description: "Zona (alias)"
  }

  dimension: nom_estado {
    type: string
    sql: ${TABLE}.nom_estado ;;
    description: "Estado"
  }

  dimension: nom_canal {
    type: string
    sql: ${TABLE}.nom_canal ;;
    description: "Canal Cliente"
  }

  dimension: nom_cliente {
    type: string
    sql: ${TABLE}.nom_cliente ;;
    description: "Cliente"
  }

  # ============================================
  # DIMENSIONES DE PERIODO (filtro Periodo)
  # ============================================

  dimension: anio {
    type: number
    sql: ${TABLE}.anio ;;
    description: "Año"
  }

  dimension: mes {
    type: number
    sql: ${TABLE}.mes ;;
    description: "Mes (anio_mes)"
  }

  dimension: semana {
    type: string
    sql: ${TABLE}.semana ;;
    description: "Semana (anio_semana)"
  }

  dimension: nombre_periodo_mostrar {
    type: string
    sql: ${TABLE}.nombre_periodo_mostrar ;;
    description: "Período para mostrar (ej. Feb-2026). Usar como filtro Periodo junto con mes/anio/semana."
  }

  dimension_group: fecha_contable {
    type: time
    sql: ${TABLE}.fecha_contable ;;
    description: "Fecha contable (usar fecha_contable_date para filtrar o Fact Ayer)."
    timeframes: [date]
  }

  # ============================================
  # MEDIDAS AUXILIARES (sumas filtradas por control, para fórmulas compuestas)
  # ============================================

  measure: total_imp_precio_entrega_mn_control_6 {
    type: sum
    sql: CASE WHEN ${TABLE}.control = 6 THEN ${TABLE}.imp_facturacion_mn END ;;
    hidden: yes
    description: "Importe precio entrega MN filtrado a control=6 (deuda). Usado por precio_deuda_total."
  }

  measure: total_toneladas_deuda_total {
    type: sum
    sql: ${TABLE}.toneladas_deuda_total ;;
    hidden: yes
    description: "Suma total de toneladas de deuda. Denominador de precio_deuda_total."
  }

  # ============================================
  # MEDIDAS PRINCIPALES: Pedidos, Deuda, Facturación, PVO, BP, histórico, mercado
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail_jerarquico*]
  }

  # ---- Bloque PEDIDOS ----

  measure: pedidos_ton {
    type: sum
    sql: ${TABLE}.toneladas_pedidas ;;
    value_format: "#,##0"
    label: "Pedidos Ton"
    description: "Pedidos Ton (suma de toneladas pedidas)."
    group_label: "Pedidos"
    drill_fields: [detail_jerarquico*]
  }

  # ---- Bloque DEUDA ----

  measure: precio_deuda_total {
    type: number
    sql: SAFE_DIVIDE(${total_imp_precio_entrega_mn_control_6}, NULLIF(${total_toneladas_deuda_total}, 0)) ;;
    label: "Deuda PM ($/ton)"
    value_format: "$#,##0.00"
    description: "Deuda PM = Precio Medio de Deuda. Fórmula: SUM(imp_precio_entrega_mn [control=6]) / SUM(toneladas_deuda_total). Equivalente a 'Precio Deuda Total MN' de Tableau."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico*]
  }

  measure: deuda_total {
    type: sum
    sql: ${TABLE}.toneladas_deuda_total ;;
    value_format: "#,##0"
    label: "Deuda Total"
    description: "Deuda Total (toneladas_deuda_total)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico*]
  }

  measure: deuda_libre {
    type: sum
    sql: ${TABLE}.toneladas_deuda_libre ;;
    value_format: "#,##0"
    label: "Deuda Libre"
    description: "Deuda Libre (toneladas_deuda_libre)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico*]
  }

  measure: deuda_autofleteo {
    type: sum
    sql: ${TABLE}.deuda_autofleteo ;;
    value_format: "#,##0"
    label: "Deuda Autofleteo"
    description: "Deuda Autofleteo (toneladas_deuda_auto_fleteo)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico*]
  }

  measure: deuda_mes_resto {
    type: sum
    sql: ${TABLE}.toneladas_deuda_mes_resto ;;
    value_format: "#,##0"
    label: "Deuda Mes Resto"
    description: "Deuda Mes Resto (toneladas_deuda_mes_resto)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico*]
  }

  measure: deuda_mes_siguiente {
    type: sum
    sql: ${TABLE}.toneladas_deuda_mes_siguiente ;;
    value_format: "#,##0"
    label: "Deuda Mes Siguiente"
    description: "Deuda Mes Siguiente (toneladas_deuda_mes_siguiente)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico*]
  }

  # ---- Bloque FACTURACIÓN ----

  measure: fact_ayer {
    type: sum
    sql: CASE
      WHEN ${TABLE}.fecha_contable = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format: "#,##0"
    label: "Fact Ayer"
    description: "Fact Ayer (toneladas facturadas el día anterior; solo valores no nulos y distintos de 0)."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico*]
  }

  measure: fact_acum {
    type: sum
    sql: ${TABLE}.toneladas_facturadas ;;
    value_format: "#,##0"
    label: "Fact Acum"
    description: "Fact Acum (suma de toneladas facturadas en el periodo)."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico*]
  }

  measure: fact_acum_importe {
    type: sum
    sql: ${TABLE}.imp_facturacion_mn ;;
    value_format: "$#,##0.00"
    label: "Fact Acum Importe"
    description: "Fact Acum importe (suma imp_precio_entrega_mn)."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico*]
  }

  measure: precio_destino_mn {
    type: number
    sql: SAFE_DIVIDE(${fact_acum_importe}, NULLIF(${fact_acum}, 0)) ;;
    value_format: "$#,##0.00"
    label: "Precio Destino MN (Fact PM)"
    description: "Precio Destino MN por tonelada = imp_precio_entrega_mn / toneladas_facturadas. Incluye flete (Datalake ID 69). NO es Precio ExWorks."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico*]
  }

  # ---- Bloque VENTAS (PVO / BP) ----

  measure: pvo {
    type: sum
    sql: ${TABLE}.toneladas_pvo ;;
    value_format: "#,##0"
    label: "PVO"
    description: "PVO (toneladas plan de ventas operativo)."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico*]
  }

  measure: pct_pvo {
    type: number
    sql: 100.0 * ${fact_acum} / NULLIF(${pvo}, 0) ;;
    value_format: "#,##0.00\"%\""
    label: "% PVO"
    description: "% PVO (Fact Acum / PVO × 100)."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico*]
  }

  measure: bp {
    type: sum
    sql: ${TABLE}.toneladas_business_plan ;;
    value_format: "#,##0"
    label: "BP"
    description: "BP (toneladas Budget Plan)."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico*]
  }

  measure: pct_bp {
    type: number
    sql: 100.0 * ${fact_acum} / NULLIF(${bp}, 0) ;;
    value_format: "#,##0.00\"%\""
    label: "% BP"
    description: "% BP (Fact Acum / BP × 100)."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico*]
  }

  # ---- Bloque HISTÓRICO ----

  measure: fact_acum_2025 {
    type: sum
    sql: CASE
      WHEN SAFE_CAST(${anio} AS INT64) = 2025
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format: "#,##0"
    label: "2025"
    description: "Toneladas facturadas en 2025 (solo valores no nulos y distintos de 0)."
    group_label: "Histórico"
    drill_fields: [detail_jerarquico*]
  }

  measure: fact_acum_2026 {
    type: sum
    sql: CASE
      WHEN SAFE_CAST(${anio} AS INT64) = 2026
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format: "#,##0"
    label: "2026"
    description: "Toneladas facturadas en 2026 (solo valores no nulos y distintos de 0)."
    group_label: "Histórico"
    drill_fields: [detail_jerarquico*]
  }

  # ---- Bloque MERCADO (EDM / CNA / Inercial) ----

  measure: edm_total {
    type: sum
    sql: ${TABLE}.edm_total ;;
    value_format: "#,##0"
    label: "EDM Total"
    description: "EDM total (toneladas_facturadas / CNA). Fórmula #40 kpis_completo.csv."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: edm_distribuido {
    type: sum
    sql: ${TABLE}.edm_distribuido ;;
    value_format: "#,##0"
    label: "EDM Distribuido"
    description: "EDM distribuido por cliente (toneladas_facturadas / CNA_DIS). Solo aplica a Varilla y Perfiles."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: cna_total {
    type: sum
    sql: ${TABLE}.vnp_total ;;
    value_format: "#,##0"
    label: "CNA"
    description: "Consumo Nacional Aparente (vnp_total). Blueprint ID 66."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: cna_distribuido {
    type: sum
    sql: ${TABLE}.vnp_distribuido ;;
    value_format: "#,##0"
    label: "CNA Distribuido"
    description: "CNA distribuido por cliente (vnp_distribuido). Solo aplica a Varilla y Perfiles."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: inercial_cna {
    type: sum
    sql: ${TABLE}.inercial_cna ;;
    value_format: "#,##0"
    label: "Inercial CNA"
    description: "Inercial de Clientes de Nuevas Adquisiciones."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: inercial_cna_distribuido {
    type: sum
    sql: ${TABLE}.inercial_cna_distribuido ;;
    value_format: "#,##0"
    label: "Inercial CNA Distribuido"
    description: "Inercial CNA distribuido por cliente. Solo aplica a Varilla y Perfiles."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: inercial_total_tons_facturadas {
    type: sum
    sql: ${TABLE}.inercial_total_tons_facturadas ;;
    value_format: "#,##0"
    label: "Inercial Total Ton Facturadas"
    description: "Inercial total en toneladas facturadas. Fórmula: tons_fact 2025 × (1 + crec_mercado_26_vs_25). Fórmula #46 kpis_completo.csv."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: inercial_total_tons_bs {
    type: sum
    sql: ${TABLE}.inercial_total_tons_bs ;;
    value_format: "#,##0"
    label: "Inercial Total Ton BS"
    description: "Inercial total toneladas business summary. Fórmula #47 kpis_completo.csv."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: promedio_cna_anio_actual {
    type: sum
    sql: ${TABLE}.promedio_cna_anio_actual ;;
    value_format: "#,##0"
    label: "Promedio CNA Año Actual"
    description: "Promedio mensual toneladas CNA año actual."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  measure: toneladas_inerciales {
    type: sum
    sql: ${TABLE}.toneladas_inerciales ;;
    value_format: "#,##0"
    label: "Toneladas Inerciales"
    description: "Toneladas inerciales (columna nativa del mart)."
    group_label: "Mercado"
    drill_fields: [detail_jerarquico*]
  }

  # ============================================
  # SETS (filtros del dashboard y drill)
  # ============================================

  set: filtros {
    fields: [
      nom_grupo_estadistico1,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3,
      nom_grupo_estadistico4,
      nombre_periodo_mostrar,
      mes,
      anio,
      semana,
      fecha_contable_date,
      nom_gerencia,
      nom_canal,
      nom_subdireccion,
      nom_zona,
      nom_estado
    ]
  }

  # Drill jerárquico principal del tablero (maqueta "Aceros Nacional y LATAM")
  # Orden: Dirección → Subdirección → Gerencia → GII (GE1) → GE2 → GE3 → GE4
  set: detail_jerarquico {
    fields: [
      nom_direccion,
      nom_subdireccion,
      nom_gerencia,
      gii,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3,
      nom_grupo_estadistico4
    ]
  }

  # Set plano con todos los campos (para vistas de detalle extendido)
  set: detail {
    fields: [
      nom_direccion,
      nom_subdireccion,
      nom_gerencia,
      gii,
      nom_grupo_estadistico1,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3,
      nom_grupo_estadistico4,
      nom_zona,
      nom_estado,
      nom_canal,
      nombre_periodo_mostrar,
      mes,
      anio,
      semana,
      pedidos_ton,
      precio_deuda_total,
      deuda_total,
      deuda_libre,
      deuda_autofleteo,
      deuda_mes_resto,
      deuda_mes_siguiente,
      fact_ayer,
      fact_acum,
      fact_acum_importe,
      precio_destino_mn,
      pvo,
      pct_pvo,
      bp,
      pct_bp,
      fact_acum_2025,
      fact_acum_2026,
      edm_total,
      edm_distribuido,
      cna_total,
      cna_distribuido,
      inercial_cna,
      inercial_cna_distribuido,
      inercial_total_tons_facturadas,
      inercial_total_tons_bs,
      promedio_cna_anio_actual,
      toneladas_inerciales
    ]
  }
}

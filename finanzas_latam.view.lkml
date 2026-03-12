# =====================================================

# Tablero por Dirección y GII (Grupo de inventario)
# Dashboard: tabla por Dirección (nom_direccion) y GII con métricas
# de pedidos y deuda. Incluye filtros y drill-down hasta
# grupo estadístico 4 y hasta gerencia.
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
        v.anio,
        v.anio_mes AS mes,
        v.anio_semana AS semana,
        v.nombre_periodo_mostrar,
        v.fecha AS fecha_contable,
        SAFE_CAST(v.toneladas_pedidas AS FLOAT64) AS toneladas_pedidas,
        CASE
          WHEN SAFE_CAST(v.toneladas_deuda_total AS FLOAT64) IS NOT NULL
            AND SAFE_CAST(v.toneladas_deuda_total AS FLOAT64) <> 0
          THEN SAFE_DIVIDE(0, SAFE_CAST(v.toneladas_deuda_total AS FLOAT64))
          ELSE NULL
        END AS deuda_pm,
        SAFE_CAST(v.toneladas_deuda_total AS FLOAT64) AS deuda_total,
        SAFE_CAST(v.toneladas_deuda_libre AS FLOAT64) AS deuda_libre,
        SAFE_CAST(v.toneladas_deuda_auto_fleteo AS FLOAT64) AS deuda_autofleteo,
        SAFE_CAST(v.toneladas_deuda_mes_resto AS FLOAT64) AS deuda_mes_resto,
        SAFE_CAST(v.toneladas_deuda_mes_siguiente AS FLOAT64) AS deuda_mes_siguiente,
        SAFE_CAST(v.toneladas_facturadas AS FLOAT64) AS toneladas_facturadas,
        SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) AS imp_facturacion_mn,
        SAFE_CAST(v.toneladas_pvo AS FLOAT64) AS toneladas_pvo,
        SAFE_CAST(v.toneladas_business_plan AS FLOAT64) AS toneladas_business_plan,
        CASE
          WHEN SAFE_CAST(v.toneladas_facturadas AS FLOAT64) IS NOT NULL
            AND SAFE_CAST(v.toneladas_facturadas AS FLOAT64) <> 0
            AND SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) IS NOT NULL
          THEN SAFE_DIVIDE(
            SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64),
            SAFE_CAST(v.toneladas_facturadas AS FLOAT64)
          )
          ELSE NULL
        END AS fact_pm_row
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
      WHERE v.nom_direccion IS NOT NULL
        AND v.anio IS NOT NULL
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
  # MEDIDAS: Pedidos, Deuda, Facturación, PVO, BP, histórico
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  measure: pedidos_ton {
    type: sum
    sql: ${TABLE}.toneladas_pedidas ;;
    value_format_name: decimal_2
    description: "Pedidos Ton (suma de toneladas pedidas)"
    drill_fields: [detail*]
  }

  measure: deuda_pm {
    type: average
    sql: ${TABLE}.deuda_pm ;;
    value_format_name: usd
    description: "Deuda PM (precio medio deuda). Solo filas con toneladas_deuda_total no nulo y distinto de 0."
    drill_fields: [detail*]
  }

  measure: deuda_total {
    type: sum
    sql: ${TABLE}.deuda_total ;;
    value_format_name: decimal_2
    description: "Deuda Total (toneladas_deuda_total)"
    drill_fields: [detail*]
  }

  measure: deuda_libre {
    type: sum
    sql: ${TABLE}.deuda_libre ;;
    value_format_name: decimal_2
    description: "Deuda Libre (toneladas_deuda_libre)"
    drill_fields: [detail*]
  }

  measure: deuda_autofleteo {
    type: sum
    sql: ${TABLE}.deuda_autofleteo ;;
    value_format_name: decimal_2
    description: "Deuda Autofleteo (toneladas_deuda_auto_fleteo)"
    drill_fields: [detail*]
  }

  measure: deuda_mes_resto {
    type: sum
    sql: ${TABLE}.deuda_mes_resto ;;
    value_format_name: decimal_2
    description: "Deuda Mes Resto (toneladas_deuda_mes_resto)"
    drill_fields: [detail*]
  }

  measure: deuda_mes_siguiente {
    type: sum
    sql: ${TABLE}.deuda_mes_siguiente ;;
    value_format_name: decimal_2
    description: "Deuda Mes Siguiente (toneladas_deuda_mes_siguiente)"
    drill_fields: [detail*]
  }

  measure: fact_ayer {
    type: sum
    sql: CASE
      WHEN ${TABLE}.fecha_contable = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format_name: decimal_2
    description: "Fact Ayer (toneladas facturadas el día anterior; solo valores no nulos y distintos de 0)"
    drill_fields: [detail*]
  }

  measure: fact_acum {
    type: sum
    sql: ${TABLE}.toneladas_facturadas ;;
    value_format_name: decimal_2
    description: "Fact Acum (suma de toneladas facturadas en el periodo)"
    drill_fields: [detail*]
  }

  measure: fact_acum_importe {
    type: sum
    sql: ${TABLE}.imp_facturacion_mn ;;
    value_format_name: usd
    description: "Fact Acum importe (suma imp_precio_entrega_mn). Fact PM = fact_acum_importe / fact_acum (table calc)."
    drill_fields: [detail*]
  }

  measure: fact_pm {
    type: average
    sql: ${TABLE}.fact_pm_row ;;
    value_format_name: usd
    description: "Fact PM (precio medio facturación). Solo filas con toneladas_facturadas e importe no nulos y toneladas <> 0."
    drill_fields: [detail*]
  }

  measure: pvo {
    type: sum
    sql: ${TABLE}.toneladas_pvo ;;
    value_format_name: decimal_2
    description: "PVO (toneladas plan de ventas operativo)"
    drill_fields: [detail*]
  }

  measure: pct_pvo {
    type: number
    sql: 100.0 * ${fact_acum} / NULLIF(${pvo}, 0) ;;
    value_format_name: decimal_2
    description: "% PVO (Fact Acum / PVO × 100). Formato: decimal; interpretar como %."
    drill_fields: [detail*]
  }

  measure: bp {
    type: sum
    sql: ${TABLE}.toneladas_business_plan ;;
    value_format_name: decimal_2
    description: "BP (toneladas Budget Plan)"
    drill_fields: [detail*]
  }

  measure: pct_bp {
    type: number
    sql: 100.0 * ${fact_acum} / NULLIF(${bp}, 0) ;;
    value_format_name: decimal_2
    description: "% BP (Fact Acum / BP × 100). Formato: decimal; interpretar como %."
    drill_fields: [detail*]
  }

  measure: fact_acum_2023 {
    type: sum
    sql: CASE
      WHEN SAFE_CAST(${anio} AS INT64) = 2023
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format_name: decimal_2
    description: "Fact Acum 2023 (solo toneladas_facturadas no nulas y distintas de 0 en ese año)"
    drill_fields: [detail*]
  }

  measure: fact_acum_2024 {
    type: sum
    sql: CASE
      WHEN SAFE_CAST(${anio} AS INT64) = 2024
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format_name: decimal_2
    description: "Fact Acum 2024 (solo toneladas_facturadas no nulas y distintas de 0 en ese año)"
    drill_fields: [detail*]
  }

  measure: fact_acum_2025 {
    type: sum
    sql: CASE
      WHEN SAFE_CAST(${anio} AS INT64) = 2025
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format_name: decimal_2
    description: "Fact Acum 2025 (solo toneladas_facturadas no nulas y distintas de 0 en ese año)"
    drill_fields: [detail*]
  }

  # ============================================
  # SETS (filtros del dashboard y detalle)
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

  # Orden del desglose: Dirección → GE1 → GE2 → GE3 → GE4 → resto → campos numéricos
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
      deuda_pm,
      deuda_total,
      deuda_libre,
      deuda_autofleteo,
      deuda_mes_resto,
      deuda_mes_siguiente,
      fact_ayer,
      fact_acum,
      fact_acum_importe,
      fact_pm,
      pvo,
      pct_pvo,
      bp,
      pct_bp,
      fact_acum_2023,
      fact_acum_2024,
      fact_acum_2025
    ]
  }
}

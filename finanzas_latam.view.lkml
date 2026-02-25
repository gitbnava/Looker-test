# =====================================================


# Tablero por Dirección y GII (Grupo de inventario)
# Dashboard: tabla por Dirección (nom_direccion) y GII con métricas
# de pedidos, desde y deuda. Incluye filtros y drill-down hasta
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
        SAFE_CAST(v.toneladas_pedidas AS FLOAT64) AS toneladas_pedidas,
        SAFE_DIVIDE(
          SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64),
          NULLIF(SAFE_CAST(v.toneladas_pedidas AS FLOAT64), 0)
        ) AS desde_pm,
        SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) AS desde_total,
        0 AS desde_libre,
        0 AS deuda_autorutas,
        0 AS deuda_metro
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

  # ============================================
  # MEDIDAS DE LA TABLA (Pedidos Ton, Desde, Deuda)
  # Los valores del diseño son solo representativos.
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
  }

  measure: desde_pm {
    type: average
    sql: ${TABLE}.desde_pm ;;
    value_format_name: usd
    description: "Desde PM (precio medio por tonelada)"
  }

  measure: desde_total {
    type: sum
    sql: ${TABLE}.desde_total ;;
    value_format_name: usd
    description: "Desde Total (importe total)"
  }

  measure: desde_libre {
    type: sum
    sql: ${TABLE}.desde_libre ;;
    value_format_name: decimal_2
    description: "Desde Libre. Sustituir por columna real del mart si aplica."
  }

  measure: deuda_autorutas {
    type: sum
    sql: ${TABLE}.deuda_autorutas ;;
    value_format_name: decimal_2
    description: "Deuda AutoRutas. Sustituir por columna real del mart si aplica."
  }

  measure: deuda_metro {
    type: sum
    sql: ${TABLE}.deuda_metro ;;
    value_format_name: decimal_2
    description: "Deuda Metro. Sustituir por columna real del mart si aplica."
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
      nom_gerencia,
      nom_canal,
      nom_subdireccion,
      nom_zona,
      nom_estado
    ]
  }

  set: detail {
    fields: [
      nom_direccion,
      gii,
      nom_grupo_estadistico1,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3,
      nom_grupo_estadistico4,
      nom_subdireccion,
      nom_gerencia,
      nom_zona,
      nom_estado,
      nom_canal,
      nombre_periodo_mostrar,
      mes,
      anio,
      semana,
      pedidos_ton,
      desde_pm,
      desde_total,
      desde_libre,
      deuda_autorutas,
      deuda_metro
    ]
  }
}

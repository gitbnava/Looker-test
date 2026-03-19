view: cuadrante_derecho_inferior {
  derived_table: {
    sql:
      WITH
      periodo_actual AS (
        SELECT CAST(FORMAT_DATE('%Y%m', CURRENT_DATE()) AS INT64) AS periodo_hasta
      ),
      meses_ordenados AS (
        SELECT
          anio,
          anio_mes AS mes,
          ROW_NUMBER() OVER (ORDER BY anio DESC, CAST(anio_mes AS INT64) DESC) AS rn
        FROM (
          SELECT DISTINCT
            SAFE_CAST(anio AS INT64) AS anio,
            anio_mes
          FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
          CROSS JOIN periodo_actual
          WHERE anio_mes IS NOT NULL
            AND anio IS NOT NULL
            AND SAFE_CAST(anio_mes AS INT64) <= periodo_hasta
            AND (
              SAFE_CAST(spread AS FLOAT64) IS NOT NULL
              OR SAFE_CAST(costo_mp AS FLOAT64) IS NOT NULL
              OR (SAFE_CAST(imp_precio_entrega_mn AS FLOAT64) IS NOT NULL AND SAFE_CAST(toneladas_facturadas AS FLOAT64) > 0)
            )
        )
      ),
      ultimos_5_meses AS (
        SELECT anio, mes
        FROM meses_ordenados
        WHERE rn <= 5
      ),
      datos_base AS (
        SELECT
          v.anio_mes AS mes,
          v.anio,
          v.nombre_periodo_mostrar,
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
          SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) AS imp_precio_entrega_mn,
          SAFE_CAST(v.toneladas_facturadas AS FLOAT64) AS toneladas_facturadas,
          SAFE_CAST(v.spread AS FLOAT64) AS spread,
          SAFE_CAST(v.costo_mp AS FLOAT64) AS costo_mp
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` v
        INNER JOIN ultimos_5_meses m
          ON SAFE_CAST(v.anio AS INT64) = m.anio AND v.anio_mes = m.mes
        WHERE v.anio_mes IS NOT NULL
          AND v.anio IS NOT NULL
      ),
      datos_por_mes AS (
        SELECT
          mes,
          anio,
          MIN(nombre_periodo_mostrar) AS nombre_periodo_mostrar,
          nom_grupo_estadistico1,
          nom_grupo_estadistico2,
          nom_grupo_estadistico3,
          nom_grupo_estadistico4,
          nom_subdireccion,
          nom_gerencia,
          nom_zona,
          nom_cliente,
          zona,
          nom_estado,
          nom_canal,
          -- Solo registros con importe y toneladas positivos para excluir notas de crédito
          SAFE_DIVIDE(
            SUM(CASE WHEN imp_precio_entrega_mn > 0 AND toneladas_facturadas > 0 THEN imp_precio_entrega_mn END),
            NULLIF(SUM(CASE WHEN imp_precio_entrega_mn > 0 AND toneladas_facturadas > 0 THEN toneladas_facturadas END), 0)
          ) AS precio_varilla_destino,
          AVG(costo_mp) AS costo_mezcla_promedio,
          AVG(spread) AS spread_promedio
        FROM datos_base
        GROUP BY mes, anio, nom_grupo_estadistico1, nom_grupo_estadistico2, nom_grupo_estadistico3, nom_grupo_estadistico4, nom_subdireccion, nom_gerencia, nom_zona, nom_cliente, zona, nom_estado, nom_canal
      ),
      con_orden AS (
        SELECT
          mes,
          anio,
          nombre_periodo_mostrar,
          nom_grupo_estadistico1,
          nom_grupo_estadistico2,
          nom_grupo_estadistico3,
          nom_grupo_estadistico4,
          nom_subdireccion,
          nom_gerencia,
          nom_zona,
          nom_cliente,
          zona,
          nom_estado,
          nom_canal,
          precio_varilla_destino,
          costo_mezcla_promedio,
          spread_promedio,
          ROW_NUMBER() OVER (ORDER BY anio ASC, CAST(mes AS INT64) ASC) AS orden
        FROM datos_por_mes
      ),
      con_variaciones AS (
        SELECT
          mes,
          anio,
          nombre_periodo_mostrar,
          nom_grupo_estadistico1,
          nom_grupo_estadistico2,
          nom_grupo_estadistico3,
          nom_grupo_estadistico4,
          nom_subdireccion,
          nom_gerencia,
          nom_zona,
          nom_cliente,
          zona,
          nom_estado,
          nom_canal,
          precio_varilla_destino,
          costo_mezcla_promedio,
          spread_promedio,
          LAG(costo_mezcla_promedio) OVER (
            PARTITION BY nom_grupo_estadistico1, nom_grupo_estadistico2, nom_grupo_estadistico3, nom_grupo_estadistico4,
                         nom_subdireccion, nom_gerencia, nom_zona, nom_cliente, zona, nom_estado, nom_canal
            ORDER BY anio ASC, CAST(mes AS INT64) ASC
          ) AS costo_mezcla_mes_anterior,
          LAG(spread_promedio) OVER (
            PARTITION BY nom_grupo_estadistico1, nom_grupo_estadistico2, nom_grupo_estadistico3, nom_grupo_estadistico4,
                         nom_subdireccion, nom_gerencia, nom_zona, nom_cliente, zona, nom_estado, nom_canal
            ORDER BY anio ASC, CAST(mes AS INT64) ASC
          ) AS spread_mes_anterior
        FROM con_orden
      )
      SELECT
        mes,
        anio,
        nombre_periodo_mostrar,
        nom_grupo_estadistico1,
        nom_grupo_estadistico2,
        nom_grupo_estadistico3,
        nom_grupo_estadistico4,
        nom_subdireccion,
        nom_gerencia,
        nom_zona,
        nom_cliente,
        zona,
        nom_estado,
        nom_canal,
        ROUND(precio_varilla_destino, 2) AS precio_varilla,
        ROUND(costo_mezcla_promedio, 2) AS costo_mezcla,
        ROUND(spread_promedio, 2) AS spread,
        ROUND(
          SAFE_DIVIDE(costo_mezcla_promedio - costo_mezcla_mes_anterior, costo_mezcla_mes_anterior) * 100,
          1
        ) AS costo_mezcla_variacion_pct,
        ROUND(
          SAFE_DIVIDE(spread_promedio - spread_mes_anterior, spread_mes_anterior) * 100,
          1
        ) AS spread_variacion_pct
      FROM con_variaciones
      ORDER BY anio ASC, CAST(mes AS INT64) ASC ;;
  }

  # ============================================
  # DIMENSIONS
  # ============================================

  dimension: mes {
    type: string
    sql: ${TABLE}.mes ;;
    description: "Mes en formato YYYYMM"
  }

  dimension: anio {
    type: number
    sql: ${TABLE}.anio ;;
    description: "Año"
  }

  dimension: nombre_periodo_mostrar {
    type: string
    sql: ${TABLE}.nombre_periodo_mostrar ;;
    description: "Período formateado para mostrar (ej: Jul-2025)"
  }

  dimension: nom_grupo_estadistico1 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico1 ;;
    description: "Nom Grupo Estadistico 1"
    suggestable: no
  }

  dimension: nom_grupo_estadistico2 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico2 ;;
    description: "Nom Grupo Estadistico 2"
    suggestable: no
  }

  dimension: nom_grupo_estadistico3 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico3 ;;
    description: "Nom Grupo Estadistico 3"
    suggestable: no
  }

  dimension: nom_grupo_estadistico4 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico4 ;;
    description: "Nom Grupo Estadistico 4"
    suggestable: no
  }

  dimension: nom_subdireccion {
    type: string
    sql: ${TABLE}.nom_subdireccion ;;
    description: "Nom Subdireccion"
    suggestable: no
  }

  dimension: nom_gerencia {
    type: string
    sql: ${TABLE}.nom_gerencia ;;
    description: "Nom Gerencia"
    suggestable: no
  }

  dimension: nom_zona {
    type: string
    sql: ${TABLE}.nom_zona ;;
    description: "Nom Zona"
    suggestable: no
  }

  dimension: nom_cliente {
    type: string
    sql: ${TABLE}.nom_cliente ;;
    description: "Nombre cliente"
    group_item_label: "Filtros"
    suggestable: no
  }

  dimension: zona {
    type: string
    sql: ${TABLE}.zona ;;
    description: "Zona"
    group_item_label: "Filtros"
    suggestable: no
  }

  dimension: nom_estado {
    type: string
    sql: ${TABLE}.nom_estado ;;
    description: "Nombre estado"
    group_item_label: "Filtros"
    suggestable: no
  }

  dimension: nom_canal {
    type: string
    sql: ${TABLE}.nom_canal ;;
    description: "Nombre canal"
    group_item_label: "Filtros"
    suggestable: no
  }

  # ============================================
  # MEASURES - Métricas principales
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  measure: precio_varilla {
    type: average
    sql: ${TABLE}.precio_varilla ;;
    value_format_name: usd
    description: "Precio Varilla (precio destino: facturación entregada por tonelada)"
  }

  measure: costo_mezcla {
    type: average
    sql: ${TABLE}.costo_mezcla ;;
    value_format_name: usd
    description: "Costo Mezcla (proxy con costo_mp hasta que exista costo mezcla chatarra digitalizado)"
  }

  measure: spread {
    type: average
    sql: ${TABLE}.spread ;;
    value_format_name: usd
    description: "Spread = Precio Exworks - Costo mezcla chatarra"
  }

  measure: costo_mezcla_variacion_pct {
    type: average
    sql: ${TABLE}.costo_mezcla_variacion_pct ;;
    value_format_name: decimal_1
    description: "Variación % costo mezcla vs mes anterior"
  }

  measure: spread_variacion_pct {
    type: average
    sql: ${TABLE}.spread_variacion_pct ;;
    value_format_name: decimal_1
    description: "Variación % spread vs mes anterior"
  }

  # ============================================
  # SETS
  # ============================================

  set: filtros {
    fields: [nom_cliente, zona, nom_estado, nom_canal, nom_subdireccion, nom_gerencia, nom_zona, nom_grupo_estadistico1, nom_grupo_estadistico2, nom_grupo_estadistico3, nom_grupo_estadistico4]

  }

  set: detail {
    fields: [
      mes,
      anio,
      nombre_periodo_mostrar,
      nom_grupo_estadistico1,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3,
      nom_grupo_estadistico4,
      nom_subdireccion,
      nom_gerencia,
      nom_zona,
      nom_cliente,
      zona,
      nom_estado,
      nom_canal,
      precio_varilla,
      costo_mezcla,
      spread,
      costo_mezcla_variacion_pct,
      spread_variacion_pct
    ]
  }
}

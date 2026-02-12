# =====================================================

# KPI Precio - Cuadrante Facturación
# Dashboard: Facturación (cuadrante Precio: valor, Vs Mes Ant, % Cambio, Tendencia)
# Fuente: ven_mart_comercial
# =====================================================
# Según datalake (Precio destino facturación): importe destino mn (ExWorks) / toneladas facturadas
# Implementado con: imp_facturado_exworks_mn / toneladas_facturadas (promedio ponderado por mes)
# =====================================================
# Ventana de periodos: todo el año 2025 + 2026 hasta la fecha actual.
# =====================================================

view: kpi_precio_facturacion {
  derived_table: {
    sql:
      WITH
      -- Agregación mensual: importe exworks y toneladas para precio promedio ponderado
      base_mensual AS (
        SELECT
          v.anio,
          v.mes,
          MAX(v.nombre_periodo_mostrar) AS nombre_periodo_mostrar,
          SUM(SAFE_CAST(v.imp_facturado_exworks_mn AS FLOAT64)) AS importe_exworks_mn,
          SUM(SAFE_CAST(v.toneladas_facturadas AS FLOAT64)) AS toneladas_facturadas
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
        WHERE v.mes IS NOT NULL
          AND v.anio IS NOT NULL
          AND v.fecha_contable IS NOT NULL
          AND v.fecha_contable <= CURRENT_DATE()
          AND (
            CAST(v.anio AS INT64) = 2025
            OR (
              CAST(v.anio AS INT64) = 2026
              AND DATE(CAST(v.anio AS INT64), CAST(SUBSTR(CAST(v.mes AS STRING), 5, 2) AS INT64), 1) <= CURRENT_DATE()
            )
          )
        GROUP BY v.anio, v.mes
      ),
      -- Precio por tonelada (Precio destino facturación = ExWorks según datalake)
      con_precio AS (
        SELECT
          anio,
          mes,
          nombre_periodo_mostrar,
          importe_exworks_mn,
          toneladas_facturadas,
          SAFE_DIVIDE(importe_exworks_mn, NULLIF(toneladas_facturadas, 0)) AS precio
        FROM base_mensual
      ),
      -- Comparativo vs mes anterior (LAG)
      con_comparativos AS (
        SELECT
          anio,
          mes,
          nombre_periodo_mostrar,
          importe_exworks_mn,
          toneladas_facturadas,
          precio,
          LAG(precio) OVER (ORDER BY anio, mes) AS precio_mes_ant
        FROM con_precio
      )
      SELECT
        anio,
        mes,
        nombre_periodo_mostrar,
        ROUND(importe_exworks_mn, 2) AS importe_exworks_mn,
        ROUND(toneladas_facturadas, 2) AS toneladas_facturadas,
        ROUND(precio, 2) AS precio,
        ROUND(precio - precio_mes_ant, 2) AS vs_mes_ant,
        ROUND(SAFE_DIVIDE(precio - precio_mes_ant, precio_mes_ant) * 100, 2) AS pct_cambio,
        CASE
          WHEN precio_mes_ant IS NULL OR (precio - precio_mes_ant) = 0 THEN 0
          WHEN (precio - precio_mes_ant) > 0 THEN 1
          ELSE -1
        END AS tendencia
      FROM con_comparativos
      WHERE toneladas_facturadas > 0
        AND precio IS NOT NULL
      ORDER BY anio DESC, mes DESC ;;
  }

  # ---------- Dimensiones ----------
  dimension: anio {
    type: number
    sql: ${TABLE}.anio ;;
    description: "Año del periodo"
  }

  dimension: mes {
    type: string
    sql: ${TABLE}.mes ;;
    description: "Mes en formato YYYYMM"
  }

  dimension: nombre_periodo_mostrar {
    type: string
    sql: ${TABLE}.nombre_periodo_mostrar ;;
    description: "Etiqueta del periodo (ej. Ene-2025)"
  }

  # ---------- Medidas principales (cuadrante Precio) ----------
  measure: precio {
    type: average
    sql: ${TABLE}.precio ;;
    value_format_name: decimal_2
    description: "Precio por tonelada (ExWorks, según datalake: importe destino mn/toneladas facturadas)"
  }

  measure: vs_mes_ant {
    type: average
    sql: ${TABLE}.vs_mes_ant ;;
    value_format_name: decimal_2
    description: "Vs Mes Ant (diferencia de precio vs mes anterior)"
  }

  measure: pct_cambio {
    type: average
    sql: ${TABLE}.pct_cambio ;;
    value_format_name: decimal_2
    description: "% Cambio (vs mes anterior)"
  }

  measure: tendencia {
    type: average
    sql: ${TABLE}.tendencia ;;
    value_format_name: decimal_2
    description: "Tendencia (1=al alza, -1=a la baja, 0=sin cambio)"
  }

  # ---------- Medidas auxiliares (drill) ----------
  measure: importe_exworks_mn {
    type: sum
    sql: ${TABLE}.importe_exworks_mn ;;
    value_format_name: decimal_2
    description: "Importe facturado ExWorks MN del mes"
  }

  measure: toneladas_facturadas {
    type: sum
    sql: ${TABLE}.toneladas_facturadas ;;
    value_format_name: decimal_2
    description: "Toneladas facturadas del mes"
  }

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  set: detail {
    fields: [anio, mes, nombre_periodo_mostrar, precio, importe_exworks_mn, toneladas_facturadas]
  }
}

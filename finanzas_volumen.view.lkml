# =====================================================

# KPI Volumen - Cuadrante Facturación
# Dashboard: Facturación (primer cuadrante - Volumen: 85,000)
# Fuente: ven_mart_comercial
# =====================================================
# Métricas: Volumen, % PVO/BP Acumulada, % PVO/BP TC,
# Vs Año Ant, Vs Mes Ant, % Cambio anual/mensual, Tendencia, Acum vs Avance del mes
# =====================================================
# Ventana de periodos: todo el año 2025 + 2026 hasta la fecha actual.
# =====================================================

view: kpi_volumen_facturacion {
  derived_table: {
    sql:
      WITH
      -- Agregación mensual por año/mes (respeta filtros de Looker por dimensiones si se agregan después)
      base_mensual AS (
        SELECT
          v.anio,
          v.mes,
          MAX(v.nombre_periodo_mostrar) AS nombre_periodo_mostrar,
          SUM(SAFE_CAST(v.toneladas_facturadas AS FLOAT64)) AS volumen,
          SUM(SAFE_CAST(v.toneladas_pvo AS FLOAT64)) AS pvo_mes,
          SUM(SAFE_CAST(v.toneladas_business_plan AS FLOAT64)) AS bp_mes
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
        WHERE v.mes IS NOT NULL
          AND v.anio IS NOT NULL
          AND v.fecha_contable IS NOT NULL
          AND v.fecha_contable <= CURRENT_DATE()
          -- Incluir todos los años (desde el más antiguo en la fuente) para que LAG tenga referencia;
          -- 2026 solo hasta la fecha actual (no meses futuros)
          AND (
            CAST(v.anio AS INT64) < 2026
            OR (
              CAST(v.anio AS INT64) = 2026
              AND DATE(CAST(v.anio AS INT64), CAST(SUBSTR(CAST(v.mes AS STRING), 5, 2) AS INT64), 1) <= CURRENT_DATE()
            )
          )
        GROUP BY v.anio, v.mes
      ),
      -- Acumulados YTD por año (suma de enero hasta mes actual)
      con_ytd AS (
        SELECT
          anio,
          mes,
          nombre_periodo_mostrar,
          volumen,
          pvo_mes,
          bp_mes,
          SUM(volumen) OVER (PARTITION BY anio ORDER BY mes) AS acum_facturado_ytd,
          SUM(pvo_mes) OVER (PARTITION BY anio ORDER BY mes) AS acum_pvo_ytd,
          SUM(bp_mes) OVER (PARTITION BY anio ORDER BY mes) AS acum_bp_ytd
        FROM base_mensual
      ),
      -- Comparativos: mismo mes año anterior y mes anterior (LAG)
      -- PARTITION BY número de mes (1-12), no por mes YYYYMM, para que mismo mes de años distintos compartan partición
      con_comparativos AS (
        SELECT
          anio,
          mes,
          nombre_periodo_mostrar,
          volumen,
          pvo_mes,
          bp_mes,
          acum_facturado_ytd,
          acum_pvo_ytd,
          acum_bp_ytd,
          LAG(volumen) OVER (
            PARTITION BY CAST(SUBSTR(CAST(mes AS STRING), 5, 2) AS INT64)
            ORDER BY anio
          ) AS volumen_anio_ant,
          LAG(volumen) OVER (ORDER BY anio, mes) AS volumen_mes_ant
        FROM con_ytd
      )
      SELECT
        anio,
        mes,
        nombre_periodo_mostrar,
        ROUND(volumen, 2) AS volumen,
        ROUND(pvo_mes, 2) AS pvo_mes,
        ROUND(bp_mes, 2) AS bp_mes,
        ROUND(acum_facturado_ytd, 2) AS acum_facturado_ytd,
        ROUND(acum_pvo_ytd, 2) AS acum_pvo_ytd,
        ROUND(acum_bp_ytd, 2) AS acum_bp_ytd,
        -- % PVO Acumulada y % BP Acumulada (TC = to date, mismo concepto)
        ROUND(SAFE_DIVIDE(acum_facturado_ytd, acum_pvo_ytd) * 100, 2) AS pct_pvo_acumulada,
        ROUND(SAFE_DIVIDE(acum_facturado_ytd, acum_bp_ytd) * 100, 2) AS pct_bp_acumulada,
        ROUND(SAFE_DIVIDE(acum_facturado_ytd, acum_pvo_ytd) * 100, 2) AS pct_pvo_tc,
        ROUND(SAFE_DIVIDE(acum_facturado_ytd, acum_bp_ytd) * 100, 2) AS pct_bp_tc,
        -- Acum vs Avance del mes: uno por fila del cuadrante (PVO y BP)
        ROUND(SAFE_DIVIDE(acum_facturado_ytd, acum_pvo_ytd) * 100, 2) AS acum_vs_avance_del_mes_pvo,
        ROUND(SAFE_DIVIDE(acum_facturado_ytd, acum_bp_ytd) * 100, 2) AS acum_vs_avance_del_mes_bp,
        -- Vs Año Ant y Vs Mes Ant (diferencias en unidades)
        ROUND(volumen - volumen_anio_ant, 2) AS vs_anio_ant,
        ROUND(volumen - volumen_mes_ant, 2) AS vs_mes_ant,
        -- % Cambio anual y mensual
        ROUND(SAFE_DIVIDE(volumen - volumen_anio_ant, volumen_anio_ant) * 100, 2) AS pct_cambio_anual,
        ROUND(SAFE_DIVIDE(volumen - volumen_mes_ant, volumen_mes_ant) * 100, 2) AS pct_cambio_mensual,
        -- Tendencia: 1 = al alza, -1 = a la baja, 0 = sin cambio (vs mes anterior)
        CASE
          WHEN volumen_mes_ant IS NULL OR (volumen - volumen_mes_ant) = 0 THEN 0
          WHEN (volumen - volumen_mes_ant) > 0 THEN 1
          ELSE -1
        END AS tendencia
      FROM con_comparativos
      WHERE volumen IS NOT NULL
        -- Solo exponer 2025 y 2026 en el cuadrante (comparativos ya calculados con historial completo)
        AND CAST(anio AS INT64) >= 2025
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

  # ---------- Medidas principales (cuadrante) ----------
  measure: volumen {
    type: sum
    sql: ${TABLE}.volumen ;;
    value_format_name: decimal_2
    description: "Volumen (toneladas facturadas en el periodo)"
  }

  measure: pct_pvo_acumulada {
    type: average
    sql: ${TABLE}.pct_pvo_acumulada ;;
    value_format_name: decimal_2
    description: "% PVO Acumulada (facturado YTD / PVO YTD)"
  }

  measure: pct_bp_acumulada {
    type: average
    sql: ${TABLE}.pct_bp_acumulada ;;
    value_format_name: decimal_2
    description: "% BP Acumulada (facturado YTD / BP YTD)"
  }

  measure: pct_pvo_tc {
    type: average
    sql: ${TABLE}.pct_pvo_tc ;;
    value_format_name: decimal_2
    description: "% PVO TC (to date, mismo que PVO Acumulada)"
  }

  measure: pct_bp_tc {
    type: average
    sql: ${TABLE}.pct_bp_tc ;;
    value_format_name: decimal_2
    description: "% BP TC (to date, mismo que BP Acumulada)"
  }

  measure: acum_vs_avance_del_mes_pvo {
    type: average
    sql: ${TABLE}.acum_vs_avance_del_mes_pvo ;;
    value_format_name: decimal_2
    description: "Acum vs Avance del mes - fila PVO (% real YTD vs PVO YTD)"
  }

  measure: acum_vs_avance_del_mes_bp {
    type: average
    sql: ${TABLE}.acum_vs_avance_del_mes_bp ;;
    value_format_name: decimal_2
    description: "Acum vs Avance del mes - fila BP (% real YTD vs BP YTD)"
  }

  measure: vs_anio_ant {
    type: average
    sql: ${TABLE}.vs_anio_ant ;;
    value_format_name: decimal_2
    description: "Vs Año Ant (diferencia en toneladas vs mismo mes año anterior)"
  }

  measure: vs_mes_ant {
    type: average
    sql: ${TABLE}.vs_mes_ant ;;
    value_format_name: decimal_2
    description: "Vs Mes Ant (diferencia en toneladas vs mes anterior)"
  }

  measure: pct_cambio_anual {
    type: average
    sql: ${TABLE}.pct_cambio_anual ;;
    value_format_name: decimal_2
    description: "% Cambio anual (vs mismo mes año anterior)"
  }

  measure: pct_cambio_mensual {
    type: average
    sql: ${TABLE}.pct_cambio_mensual ;;
    value_format_name: decimal_2
    description: "% Cambio mensual (vs mes anterior)"
  }

  measure: tendencia {
    type: average
    sql: ${TABLE}.tendencia ;;
    value_format_name: decimal_2
    description: "Tendencia (1=al alza, -1=a la baja, 0=sin cambio)"
  }

  # ---------- Medidas auxiliares (drill) ----------
  measure: pvo_mes {
    type: sum
    sql: ${TABLE}.pvo_mes ;;
    value_format_name: decimal_2
    description: "PVO del mes"
  }

  measure: bp_mes {
    type: sum
    sql: ${TABLE}.bp_mes ;;
    value_format_name: decimal_2
    description: "Business Plan del mes"
  }

  measure: acum_facturado_ytd {
    type: sum
    sql: ${TABLE}.acum_facturado_ytd ;;
    value_format_name: decimal_2
    description: "Toneladas facturadas acumuladas YTD"
  }

  measure: acum_pvo_ytd {
    type: sum
    sql: ${TABLE}.acum_pvo_ytd ;;
    value_format_name: decimal_2
    description: "PVO acumulado YTD"
  }

  measure: acum_bp_ytd {
    type: sum
    sql: ${TABLE}.acum_bp_ytd ;;
    value_format_name: decimal_2
    description: "BP acumulado YTD"
  }

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  set: detail {
    fields: [anio, mes, nombre_periodo_mostrar, volumen, pvo_mes, bp_mes]
  }
}

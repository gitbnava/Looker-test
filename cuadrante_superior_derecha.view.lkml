view: cuadrante_superior_derecha {
  derived_table: {
    sql:
      -- =====================================================
      -- QUERY PARA CUADRANTE SUPERIOR DERECHO
      -- Bubble Chart: Indice Precio vs Spread por Semana
      -- =====================================================

      WITH
      -- Calcular la semana actual para filtrar semanas futuras
      semana_actual_calculada AS (
        SELECT
          CAST(EXTRACT(YEAR FROM CURRENT_DATE()) AS STRING) ||
          LPAD(CAST(EXTRACT(ISOWEEK FROM CURRENT_DATE()) AS STRING), 2, '0') AS semana_actual_str
      ),
      -- Encontrar las últimas 6 semanas disponibles con datos válidos
      semanas_disponibles AS (
        SELECT DISTINCT semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        CROSS JOIN semana_actual_calculada
        WHERE fecha_contable IS NOT NULL
          AND semana IS NOT NULL
          AND semana <= (SELECT semana_actual_str FROM semana_actual_calculada)
          AND fecha_contable <= CURRENT_DATE()
          AND (
            spread IS NOT NULL
            OR (
              SAFE_CAST(toneladas_pedidas AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(toneladas_pedidas AS FLOAT64) != 0
              AND SAFE_CAST(toneladas_caida_de_pedidos AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(imp_precio_entrega_mn AS FLOAT64) IS NOT NULL
              AND precio_pulso IS NOT NULL
              AND SAFE_CAST(precio_pulso AS FLOAT64) > 0
            )
          )
          AND toneladas_facturadas IS NOT NULL
          AND SAFE_CAST(toneladas_facturadas AS FLOAT64) > 0
        ORDER BY semana DESC
        LIMIT 6
      ),
      semana_limite AS (
        SELECT MIN(semana) AS semana_limite_str
        FROM semanas_disponibles
      ),

      datos_base AS (
        SELECT
          semana,
          mes,
          anio,
          trimestre,
          nombre_periodo_mostrar,
          fecha_contable,
          SAFE_CAST(spread AS FLOAT64) AS spread,
          SAFE_CAST(costo_mp AS FLOAT64) AS costo_mp,
          -- Calcular precio_caida_pedidos según la fórmula proporcionada
          CASE
            WHEN SAFE_CAST(toneladas_pedidas AS FLOAT64) != 0
              AND SAFE_CAST(toneladas_pedidas AS FLOAT64) IS NOT NULL
            THEN SAFE_CAST(toneladas_caida_de_pedidos AS FLOAT64) *
                 SAFE_DIVIDE(SAFE_CAST(imp_precio_entrega_mn AS FLOAT64),
                             SAFE_CAST(toneladas_pedidas AS FLOAT64))
            ELSE NULL
          END AS precio_caida_pedidos,
          SAFE_CAST(precio_pulso AS FLOAT64) AS precio_pulso,
          SAFE_CAST(toneladas_facturadas AS FLOAT64) AS toneladas_facturadas,
          SAFE_CAST(imp_facturado_exworks_mn AS FLOAT64) AS imp_facturado_exworks_mn
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        CROSS JOIN semana_limite
        WHERE semana IS NOT NULL
          AND fecha_contable IS NOT NULL
          AND semana >= (SELECT semana_limite_str FROM semana_limite)
          AND (
            spread IS NOT NULL
            OR (
              SAFE_CAST(toneladas_pedidas AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(toneladas_pedidas AS FLOAT64) != 0
              AND SAFE_CAST(toneladas_caida_de_pedidos AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(imp_precio_entrega_mn AS FLOAT64) IS NOT NULL
              AND precio_pulso IS NOT NULL
              AND SAFE_CAST(precio_pulso AS FLOAT64) > 0
            )
          )
          AND toneladas_facturadas IS NOT NULL
          AND SAFE_CAST(toneladas_facturadas AS FLOAT64) > 0
      ),

      datos_con_indice AS (
        SELECT
          semana,
          mes,
          anio,
          trimestre,
          nombre_periodo_mostrar,
          fecha_contable,
          spread,
          costo_mp,
          precio_caida_pedidos,
          precio_pulso,
          toneladas_facturadas,
          imp_facturado_exworks_mn,
          -- Calcular Indice Precio: precio_caida_pedidos / precio_pulso
          SAFE_DIVIDE(precio_caida_pedidos, precio_pulso) AS indice_precio
        FROM datos_base
      ),

      datos_agregados AS (
        SELECT
          semana,
          MIN(mes) AS mes,
          MIN(anio) AS anio,
          MIN(trimestre) AS trimestre,
          MIN(nombre_periodo_mostrar) AS nombre_periodo_mostrar,
          MIN(fecha_contable) AS fecha_contable_min,
          MAX(fecha_contable) AS fecha_contable_max,
          -- Promedio de Spread
          AVG(spread) AS spread_promedio,
          -- Promedio de Indice Precio
          AVG(indice_precio) AS indice_precio_promedio,
          -- Suma de toneladas para tamaño de burbuja
          SUM(toneladas_facturadas) AS toneladas_totales,
          -- Estadísticas adicionales para validación
          COUNT(*) AS registros,
          COUNT(DISTINCT fecha_contable) AS dias_distintos
        FROM datos_con_indice
        WHERE indice_precio IS NOT NULL
          AND spread IS NOT NULL
        GROUP BY semana
      )

      SELECT
        semana,
        mes,
        anio,
        trimestre,
        nombre_periodo_mostrar,
        fecha_contable_min,
        fecha_contable_max,
        -- Medidas principales para el bubble chart
        ROUND(indice_precio_promedio, 4) AS indice_precio,
        ROUND(spread_promedio, 2) AS spread,
        ROUND(toneladas_totales, 2) AS toneladas_facturadas,
        -- Campos adicionales para referencia
        registros,
        dias_distintos,
        -- Formato de semana para etiquetas (ej: "S45" desde "202545")
        CONCAT('S', SUBSTR(CAST(semana AS STRING), -2)) AS semana_label
      FROM datos_agregados
      WHERE indice_precio_promedio IS NOT NULL
        AND spread_promedio IS NOT NULL
        AND toneladas_totales > 0
      ORDER BY semana DESC ;;
  }

  # ============================================
  # DIMENSIONS (Campos para agrupar/filtrar)
  # ============================================

  dimension: semana {
    type: string
    sql: ${TABLE}.semana ;;
    description: "Semana en formato YYYYWW"
  }

  dimension: semana_label {
    type: string
    sql: ${TABLE}.semana_label ;;
    description: "Etiqueta de semana formateada (ej: S45)"
  }

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

  dimension: trimestre {
    type: string
    sql: ${TABLE}.trimestre ;;
    description: "Trimestre"
  }

  dimension: nombre_periodo_mostrar {
    type: string
    sql: ${TABLE}.nombre_periodo_mostrar ;;
    description: "Período formateado para mostrar"
  }

  dimension: fecha_contable_min {
    type: date
    datatype: date
    sql: ${TABLE}.fecha_contable_min ;;
    description: "Fecha contable mínima de la semana"
  }

  dimension: fecha_contable_max {
    type: date
    datatype: date
    sql: ${TABLE}.fecha_contable_max ;;
    description: "Fecha contable máxima de la semana"
  }

  # ============================================
  # MEASURES (Valores numéricos calculables)
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  measure: indice_precio {
    type: average
    sql: ${TABLE}.indice_precio ;;
    value_format_name: decimal_4
    description: "Índice de precio (precio_caida / pulso)"
  }

  measure: spread {
    type: average
    sql: ${TABLE}.spread ;;
    value_format_name: usd
    description: "Spread (Precio Exworks - Costo MP)"
  }

  measure: toneladas_facturadas {
    type: sum
    sql: ${TABLE}.toneladas_facturadas ;;
    value_format_name: decimal_2
    description: "Toneladas facturadas (para tamaño de burbuja)"
  }

  measure: registros {
    type: sum
    sql: ${TABLE}.registros ;;
    value_format_name: decimal_0
    description: "Número de registros agregados"
  }

  measure: dias_distintos {
    type: sum
    sql: ${TABLE}.dias_distintos ;;
    value_format_name: decimal_0
    description: "Número de días distintos en la semana"
  }

  # ============================================
  # SETS (Agrupaciones de campos)
  # ============================================

  set: detail {
    fields: [
      semana,
      semana_label,
      mes,
      anio,
      trimestre,
      nombre_periodo_mostrar,
      fecha_contable_min,
      fecha_contable_max,
      indice_precio,
      spread,
      toneladas_facturadas,
      registros,
      dias_distintos
    ]
  }
}

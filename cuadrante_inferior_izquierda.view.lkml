view: cuadrante_izquierdo_inferior {
  derived_table: {
    sql:
      -- =====================================================
      -- QUERY OPTIMIZADO PARA CUADRANTE INFERIOR IZQUIERDO
      -- Medidor de Precio + KPIs + Gráfico Combinado Temporal
      -- Optimizado para reducir lecturas y procesamiento
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
        SELECT DISTINCT anio_semana AS semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        CROSS JOIN semana_actual_calculada
        WHERE fecha IS NOT NULL
          AND anio_semana IS NOT NULL
          AND anio_semana <= (SELECT semana_actual_str FROM semana_actual_calculada)
          AND fecha <= CURRENT_DATE()
          AND Tipo_Cambio IS NOT NULL
          AND SAFE_CAST(Tipo_Cambio AS FLOAT64) > 0
          AND (
            -- precio_caida_pedidos es calculado; considerar semanas con insumos para calcularlo
            (
              SAFE_CAST(toneladas_pedidas AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(toneladas_pedidas AS FLOAT64) != 0
              AND SAFE_CAST(toneladas_caida_de_pedidos AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(imp_precio_entrega_mn AS FLOAT64) IS NOT NULL
            )
            OR Platts_total IS NOT NULL
            OR precio_senial IS NOT NULL
            OR toneladas_pvo IS NOT NULL
            OR toneladas_facturadas IS NOT NULL
          )
        ORDER BY anio_semana DESC
        LIMIT 6
      ),

      -- Una sola lectura de tabla base con todos los campos necesarios
      datos_base_unificados AS (
        SELECT
          v.anio_semana AS semana,
          v.anio_mes AS mes,
          v.anio,
          v.trimestre,
          v.nombre_periodo_mostrar,
          v.fecha AS fecha_contable,
          -- Campos para precios internacionales (usando SAFE_CAST)
          SAFE_CAST(v.Tipo_Cambio AS FLOAT64) AS Tipo_Cambio,
          SAFE_CAST(v.Rebar_FOB_Turkey AS FLOAT64) AS precio_usd_turkey_rebar,
          SAFE_CAST(v.Rebar_FOB_Spain AS FLOAT64) AS precio_usd_spain_rebar,
          SAFE_CAST(v.Precio_Varilla_Malasia AS FLOAT64) AS precio_usd_malasia_varilla,
          SAFE_CAST(v.Angulo_Comercial_Turkey AS FLOAT64) AS precio_usd_turkey_angulo,
          SAFE_CAST(v.Angulo_Comercial_China AS FLOAT64) AS precio_usd_china_angulo,
          SAFE_CAST(v.Vigas_IPN_Turkey AS FLOAT64) AS precio_usd_turkey_vigas,
          SAFE_CAST(v.Pulso_Vigas_Int AS FLOAT64) AS precio_usd_pulso_vigas,
          SAFE_CAST(v.Indice_AMM_Sur_Europa AS FLOAT64) AS precio_usd_amm_europa,
          SAFE_CAST(v.indice_AMM_Sudeste_Asiatico AS FLOAT64) AS precio_usd_amm_asia,
          -- precio_caida_pedidos es calculado (no existe en el mart): toneladas_caida_de_pedidos * (imp_precio_entrega_mn / toneladas_pedidas)
          CASE
            WHEN SAFE_CAST(v.toneladas_pedidas AS FLOAT64) != 0
              AND SAFE_CAST(v.toneladas_pedidas AS FLOAT64) IS NOT NULL
            THEN SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) *
                 SAFE_DIVIDE(SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64),
                             SAFE_CAST(v.toneladas_pedidas AS FLOAT64))
            ELSE NULL
          END AS precio_caida_pedidos,
          SAFE_CAST(v.Platts_total AS FLOAT64) AS platts_total,
          SAFE_CAST(v.precio_senial AS FLOAT64) AS senal_de_precio,
          SAFE_CAST(v.precio_senial AS FLOAT64) AS precio_senial,
          SAFE_CAST(v.toneladas_pvo AS FLOAT64) AS toneladas_pvo,
          SAFE_CAST(v.toneladas_facturadas AS FLOAT64) AS toneladas_facturadas,
          SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) AS toneladas_caida_de_pedidos,
          SAFE_CAST(v.imp_facturado_exworks_mn AS FLOAT64) AS imp_facturado_exworks_mn
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
        WHERE v.anio_semana IS NOT NULL
          AND v.fecha IS NOT NULL
          AND v.anio_semana IN (SELECT semana FROM semanas_disponibles)
          AND v.Tipo_Cambio IS NOT NULL
          AND SAFE_CAST(v.Tipo_Cambio AS FLOAT64) > 0
      ),

      -- Unificar precios internacionales convertidos a MXN (una sola pasada)
      precios_importacion_unificados AS (
        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_turkey_rebar IS NOT NULL AND precio_usd_turkey_rebar > 0
            THEN Tipo_Cambio * precio_usd_turkey_rebar ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_turkey_rebar IS NOT NULL AND precio_usd_turkey_rebar > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_spain_rebar IS NOT NULL AND precio_usd_spain_rebar > 0
            THEN Tipo_Cambio * precio_usd_spain_rebar ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_spain_rebar IS NOT NULL AND precio_usd_spain_rebar > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_malasia_varilla IS NOT NULL AND precio_usd_malasia_varilla > 0
            THEN Tipo_Cambio * precio_usd_malasia_varilla ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_malasia_varilla IS NOT NULL AND precio_usd_malasia_varilla > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_turkey_angulo IS NOT NULL AND precio_usd_turkey_angulo > 0
            THEN Tipo_Cambio * precio_usd_turkey_angulo ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_turkey_angulo IS NOT NULL AND precio_usd_turkey_angulo > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_china_angulo IS NOT NULL AND precio_usd_china_angulo > 0
            THEN Tipo_Cambio * precio_usd_china_angulo ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_china_angulo IS NOT NULL AND precio_usd_china_angulo > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_turkey_vigas IS NOT NULL AND precio_usd_turkey_vigas > 0
            THEN Tipo_Cambio * precio_usd_turkey_vigas ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_turkey_vigas IS NOT NULL AND precio_usd_turkey_vigas > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_pulso_vigas IS NOT NULL AND precio_usd_pulso_vigas > 0
            THEN Tipo_Cambio * precio_usd_pulso_vigas ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_pulso_vigas IS NOT NULL AND precio_usd_pulso_vigas > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_amm_europa IS NOT NULL AND precio_usd_amm_europa > 0
            THEN Tipo_Cambio * precio_usd_amm_europa ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_amm_europa IS NOT NULL AND precio_usd_amm_europa > 0

        UNION ALL

        SELECT
          semana,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_amm_asia IS NOT NULL AND precio_usd_amm_asia > 0
            THEN Tipo_Cambio * precio_usd_amm_asia ELSE NULL END AS precio_mxn
        FROM datos_base_unificados
        WHERE precio_usd_amm_asia IS NOT NULL AND precio_usd_amm_asia > 0
      ),

      -- Agregar precio importación por semana ANTES del JOIN principal
      precio_importacion_por_semana AS (
        SELECT
          semana,
          AVG(precio_mxn) AS precio_importacion_promedio
        FROM precios_importacion_unificados
        WHERE precio_mxn IS NOT NULL
        GROUP BY semana
      ),

      -- Agregación final por semana con todos los cálculos
      datos_agregados AS (
        SELECT
          db.semana,
          MIN(db.mes) AS mes,
          MIN(db.anio) AS anio,
          MIN(db.trimestre) AS trimestre,
          MIN(db.nombre_periodo_mostrar) AS nombre_periodo_mostrar,
          MIN(db.fecha_contable) AS fecha_contable_min,
          MAX(db.fecha_contable) AS fecha_contable_max,
          -- Promedios para líneas de precio
          AVG(db.precio_caida_pedidos) AS precio_caida_promedio,
          AVG(db.platts_total) AS platts_promedio,
          AVG(COALESCE(db.senal_de_precio, db.precio_senial)) AS senal_precio_promedio,
          MAX(pi.precio_importacion_promedio) AS precio_importacion_promedio,
          -- Sumas para volumen
          SUM(db.toneladas_pvo) AS toneladas_pvo_total,
          SUM(db.toneladas_facturadas) AS toneladas_facturadas_total,
          SUM(db.toneladas_caida_de_pedidos) AS toneladas_caida_de_pedidos_total,
          -- Cálculo de precio OPVO usando SAFE_DIVIDE
          SAFE_DIVIDE(SUM(db.imp_facturado_exworks_mn), SUM(db.toneladas_pvo)) AS precio_opvo_calculado
        FROM datos_base_unificados db
        LEFT JOIN precio_importacion_por_semana pi
          ON db.semana = pi.semana
        WHERE db.precio_caida_pedidos IS NOT NULL
        GROUP BY db.semana
      ),

      -- Estadísticas globales calculadas una sola vez (fuera de window functions)
      estadisticas_globales AS (
        SELECT
          AVG(precio_caida_promedio) AS precio_caida_promedio_global,
          STDDEV(precio_caida_promedio) AS precio_caida_stddev_global,
          MIN(precio_caida_promedio) AS precio_minimo_historico,
          MAX(precio_caida_promedio) AS precio_maximo_historico
        FROM datos_agregados
      ),

      -- Agregar cálculos de variación semanal y límites
      datos_con_variaciones AS (
        SELECT
          da.semana,
          da.mes,
          da.anio,
          da.trimestre,
          da.nombre_periodo_mostrar,
          da.fecha_contable_min,
          da.fecha_contable_max,
          da.precio_caida_promedio,
          da.platts_promedio,
          da.senal_precio_promedio,
          da.precio_importacion_promedio,
          da.toneladas_pvo_total,
          da.toneladas_facturadas_total,
          da.toneladas_caida_de_pedidos_total,
          da.precio_opvo_calculado,
          -- Límites usando estadísticas globales
          eg.precio_caida_promedio_global + eg.precio_caida_stddev_global AS limite_superior,
          eg.precio_caida_promedio_global - eg.precio_caida_stddev_global AS limite_inferior,
          eg.precio_minimo_historico,
          eg.precio_maximo_historico,
          -- Precio semana anterior usando LAG
          LAG(da.precio_caida_promedio) OVER (ORDER BY da.semana) AS precio_semana_anterior,
          -- Variación porcentual semana a semana para toneladas usando SAFE_DIVIDE
          LAG(da.toneladas_facturadas_total) OVER (ORDER BY da.semana) AS toneladas_semana_anterior,
          ROUND(SAFE_DIVIDE(
            (da.toneladas_facturadas_total - LAG(da.toneladas_facturadas_total) OVER (ORDER BY da.semana)),
            LAG(da.toneladas_facturadas_total) OVER (ORDER BY da.semana)
          ) * 100, 2) AS variacion_porcentual_toneladas
        FROM datos_agregados da
        CROSS JOIN estadisticas_globales eg
      )

      SELECT
        semana,
        mes,
        anio,
        trimestre,
        nombre_periodo_mostrar,
        fecha_contable_min,
        fecha_contable_max,
        -- Valores para KPIs y medidor
        ROUND(precio_caida_promedio, 2) AS precio_caida_promedio,
        ROUND(limite_superior, 2) AS limite_superior,
        ROUND(limite_inferior, 2) AS limite_inferior,
        ROUND(precio_semana_anterior, 2) AS precio_semana_anterior,
        ROUND(precio_minimo_historico, 2) AS precio_minimo_historico,
        ROUND(precio_maximo_historico, 2) AS precio_maximo_historico,
        -- Valores para líneas de precio
        ROUND(platts_promedio, 2) AS platts_promedio,
        ROUND(senal_precio_promedio, 2) AS senal_precio_promedio,
        ROUND(precio_importacion_promedio, 2) AS precio_importacion_promedio,
        ROUND(precio_opvo_calculado, 2) AS precio_opvo_calculado,
        -- Valores para barras de volumen
        ROUND(toneladas_pvo_total, 2) AS toneladas_pvo_total,
        ROUND(toneladas_facturadas_total, 2) AS toneladas_facturadas_total,
        ROUND(toneladas_caida_de_pedidos_total, 2) AS toneladas_caida_de_pedidos_total,
        -- Variación porcentual
        variacion_porcentual_toneladas,
        -- Formato de semana para etiquetas
        CONCAT('S', SUBSTR(CAST(semana AS STRING), -2)) AS semana_label
      FROM datos_con_variaciones
      WHERE precio_caida_promedio IS NOT NULL
      ORDER BY semana ASC ;;
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

  # KPIs y Medidor
  measure: precio_caida_promedio {
    type: average
    sql: ${TABLE}.precio_caida_promedio ;;
    value_format_name: usd
    description: "Precio caída promedio (para medidor y KPIs)"
  }

  measure: limite_superior {
    type: average
    sql: ${TABLE}.limite_superior ;;
    value_format_name: usd
    description: "Límite superior (Promedio + STDDEV)"
  }

  measure: limite_inferior {
    type: average
    sql: ${TABLE}.limite_inferior ;;
    value_format_name: usd
    description: "Límite inferior (Promedio - STDDEV)"
  }

  measure: precio_semana_anterior {
    type: average
    sql: ${TABLE}.precio_semana_anterior ;;
    value_format_name: usd
    description: "Precio caída semana anterior"
  }

  measure: precio_minimo_historico {
    type: min
    sql: ${TABLE}.precio_minimo_historico ;;
    value_format_name: usd
    description: "Precio mínimo histórico (para rango del medidor)"
  }

  measure: precio_maximo_historico {
    type: max
    sql: ${TABLE}.precio_maximo_historico ;;
    value_format_name: usd
    description: "Precio máximo histórico (para rango del medidor)"
  }

  # Líneas de Precio
  measure: platts_promedio {
    type: average
    sql: ${TABLE}.platts_promedio ;;
    value_format_name: usd
    description: "Platts promedio por semana"
  }

  measure: senal_precio_promedio {
    type: average
    sql: ${TABLE}.senal_precio_promedio ;;
    value_format_name: usd
    description: "Señal de precio promedio por semana"
  }

  measure: precio_importacion_promedio {
    type: average
    sql: ${TABLE}.precio_importacion_promedio ;;
    value_format_name: usd
    description: "Precio importación promedio por semana"
  }

  measure: precio_opvo_calculado {
    type: average
    sql: ${TABLE}.precio_opvo_calculado ;;
    value_format_name: usd
    description: "Precio OPVO calculado (si se necesita como precio)"
  }

  # Volumen (Barras)
  measure: toneladas_pvo_total {
    type: sum
    sql: ${TABLE}.toneladas_pvo_total ;;
    value_format_name: decimal_2
    description: "Toneladas PVO totales por semana"
  }

  measure: toneladas_facturadas_total {
    type: sum
    sql: ${TABLE}.toneladas_facturadas_total ;;
    value_format_name: decimal_2
    description: "Toneladas facturadas totales por semana"
  }

  measure: toneladas_caida_de_pedidos_total {
    type: sum
    sql: ${TABLE}.toneladas_caida_de_pedidos_total ;;
    value_format_name: decimal_2
    description: "Toneladas caída de pedidos totales por semana"
  }

  measure: variacion_porcentual_toneladas {
    type: average
    sql: ${TABLE}.variacion_porcentual_toneladas ;;
    value_format_name: decimal_2
    description: "Variación porcentual semana a semana de toneladas"
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
      precio_caida_promedio,
      limite_superior,
      limite_inferior,
      precio_semana_anterior,
      precio_minimo_historico,
      precio_maximo_historico,
      platts_promedio,
      senal_precio_promedio,
      precio_importacion_promedio,
      precio_opvo_calculado,
      toneladas_pvo_total,
      toneladas_facturadas_total,
      toneladas_caida_de_pedidos_total,
      variacion_porcentual_toneladas
    ]
  }
}

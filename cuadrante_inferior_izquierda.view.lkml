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
      -- Encontrar las últimas 5 semanas disponibles con datos válidos
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

      -- Precios de importación y tipo de cambio agregados por semana (de cualquier fila con esos campos)
      -- Desacoplado de GE para que funcione con cualquier filtro de producto
      ref_por_semana AS (
      SELECT
      anio_semana AS semana,
      AVG(SAFE_CAST(Tipo_Cambio AS FLOAT64)) AS Tipo_Cambio,
      AVG(CASE WHEN SAFE_CAST(Platts_total AS FLOAT64) > 0 THEN SAFE_CAST(Platts_total AS FLOAT64) END) AS platts_total,
      AVG(CASE WHEN SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) END) AS precio_usd_turkey_rebar,
      AVG(CASE WHEN SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) > 0 THEN SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) END) AS precio_usd_spain_rebar,
      AVG(CASE WHEN SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) > 0 THEN SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) END) AS precio_usd_malasia_varilla,
      AVG(CASE WHEN SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) END) AS precio_usd_turkey_angulo,
      AVG(CASE WHEN SAFE_CAST(Angulo_Comercial_China AS FLOAT64) > 0 THEN SAFE_CAST(Angulo_Comercial_China AS FLOAT64) END) AS precio_usd_china_angulo,
      AVG(CASE WHEN SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) END) AS precio_usd_turkey_vigas,
      AVG(CASE WHEN SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) > 0 THEN SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) END) AS precio_usd_pulso_vigas,
      AVG(CASE WHEN SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) > 0 THEN SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) END) AS precio_usd_amm_europa,
      AVG(CASE WHEN SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) > 0 THEN SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) END) AS precio_usd_amm_asia
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
      WHERE anio_semana IN (SELECT semana FROM semanas_disponibles)
      AND SAFE_CAST(Tipo_Cambio AS FLOAT64) > 0
      GROUP BY anio_semana
      ),

      -- nom_cliente, zona, nom_estado, nom_canal se mantienen en todo el recorrido para filtros en tiles
      -- Los precios de importación vienen del CTE semanal via JOIN, no de la fila individual
      datos_base_unificados AS (
      SELECT
      v.anio_semana AS semana,
      v.anio_mes AS mes,
      v.anio,
      v.trimestre,
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
      v.fecha AS fecha_contable,
      r.Tipo_Cambio,
      r.precio_usd_turkey_rebar,
      r.precio_usd_spain_rebar,
      r.precio_usd_malasia_varilla,
      r.precio_usd_turkey_angulo,
      r.precio_usd_china_angulo,
      r.precio_usd_turkey_vigas,
      r.precio_usd_pulso_vigas,
      r.precio_usd_amm_europa,
      r.precio_usd_amm_asia,
      -- precio_caida_pedidos: precio por tonelada ($/ton) = imp_precio_entrega_mn / toneladas_pedidas
      CASE
      WHEN SAFE_CAST(v.toneladas_pedidas AS FLOAT64) > 0
      AND SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) > 0
      THEN SAFE_DIVIDE(
      SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64),
      SAFE_CAST(v.toneladas_pedidas AS FLOAT64)
      )
      ELSE NULL
      END AS precio_caida_pedidos,
      r.platts_total,
      SAFE_CAST(v.precio_senial AS FLOAT64) AS precio_senial,
      SAFE_CAST(v.toneladas_pvo AS FLOAT64) AS toneladas_pvo,
      SAFE_CAST(v.toneladas_facturadas AS FLOAT64) AS toneladas_facturadas,
      SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) AS toneladas_caida_de_pedidos,
      SAFE_CAST(v.imp_facturado_exworks_mn AS FLOAT64) AS imp_facturado_exworks_mn
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
      INNER JOIN ref_por_semana r ON v.anio_semana = r.semana
      WHERE v.anio_semana IS NOT NULL
      AND v.fecha IS NOT NULL
      AND v.anio_semana IN (SELECT semana FROM semanas_disponibles)
      ),

      -- Precio de importación por semana usando el CTE semanal ya calculado
      precios_importacion_unificados AS (
      SELECT semana, Tipo_Cambio * precio_usd_turkey_rebar AS precio_mxn
      FROM ref_por_semana WHERE precio_usd_turkey_rebar IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_spain_rebar FROM ref_por_semana WHERE precio_usd_spain_rebar IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_malasia_varilla FROM ref_por_semana WHERE precio_usd_malasia_varilla IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_turkey_angulo FROM ref_por_semana WHERE precio_usd_turkey_angulo IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_china_angulo FROM ref_por_semana WHERE precio_usd_china_angulo IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_turkey_vigas FROM ref_por_semana WHERE precio_usd_turkey_vigas IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_pulso_vigas FROM ref_por_semana WHERE precio_usd_pulso_vigas IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_amm_europa FROM ref_por_semana WHERE precio_usd_amm_europa IS NOT NULL
      UNION ALL
      SELECT semana, Tipo_Cambio * precio_usd_amm_asia FROM ref_por_semana WHERE precio_usd_amm_asia IS NOT NULL
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
      MIN(db.nom_grupo_estadistico1) AS nom_grupo_estadistico1,
      MIN(db.nom_grupo_estadistico2) AS nom_grupo_estadistico2,
      MIN(db.nom_grupo_estadistico3) AS nom_grupo_estadistico3,
      MIN(db.nom_grupo_estadistico4) AS nom_grupo_estadistico4,
      MIN(db.nom_subdireccion) AS nom_subdireccion,
      MIN(db.nom_gerencia) AS nom_gerencia,
      MIN(db.nom_zona) AS nom_zona,
      MIN(db.nom_cliente) AS nom_cliente,
      MIN(db.zona) AS zona,
      MIN(db.nom_estado) AS nom_estado,
      MIN(db.nom_canal) AS nom_canal,
      MIN(db.fecha_contable) AS fecha_contable_min,
      MAX(db.fecha_contable) AS fecha_contable_max,
      -- Promedios para líneas de precio
      AVG(db.precio_caida_pedidos) AS precio_caida_promedio,
      AVG(db.platts_total) AS platts_promedio,
      AVG(db.precio_senial) AS senal_precio_promedio,
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
      GROUP BY db.semana, db.nom_grupo_estadistico1, db.nom_grupo_estadistico2, db.nom_grupo_estadistico3, db.nom_grupo_estadistico4, db.nom_subdireccion, db.nom_gerencia, db.nom_zona, db.nom_cliente, db.zona, db.nom_estado, db.nom_canal
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
      da.nom_grupo_estadistico1,
      da.nom_grupo_estadistico2,
      da.nom_grupo_estadistico3,
      da.nom_grupo_estadistico4,
      da.nom_subdireccion,
      da.nom_gerencia,
      da.nom_zona,
      da.nom_cliente,
      da.zona,
      da.nom_estado,
      da.nom_canal,
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
      -- Precio semana anterior usando LAG con PARTITION BY para no mezclar segmentos
      LAG(da.precio_caida_promedio) OVER (
      PARTITION BY da.nom_grupo_estadistico1, da.nom_grupo_estadistico2, da.nom_grupo_estadistico3, da.nom_grupo_estadistico4,
      da.nom_subdireccion, da.nom_gerencia, da.nom_zona, da.nom_cliente, da.zona, da.nom_estado, da.nom_canal
      ORDER BY da.semana
      ) AS precio_semana_anterior,
      LAG(da.toneladas_facturadas_total) OVER (
      PARTITION BY da.nom_grupo_estadistico1, da.nom_grupo_estadistico2, da.nom_grupo_estadistico3, da.nom_grupo_estadistico4,
      da.nom_subdireccion, da.nom_gerencia, da.nom_zona, da.nom_cliente, da.zona, da.nom_estado, da.nom_canal
      ORDER BY da.semana
      ) AS toneladas_semana_anterior,
      ROUND(SAFE_DIVIDE(
      (da.toneladas_facturadas_total - LAG(da.toneladas_facturadas_total) OVER (
      PARTITION BY da.nom_grupo_estadistico1, da.nom_grupo_estadistico2, da.nom_grupo_estadistico3, da.nom_grupo_estadistico4,
      da.nom_subdireccion, da.nom_gerencia, da.nom_zona, da.nom_cliente, da.zona, da.nom_estado, da.nom_canal
      ORDER BY da.semana
      )),
      LAG(da.toneladas_facturadas_total) OVER (
      PARTITION BY da.nom_grupo_estadistico1, da.nom_grupo_estadistico2, da.nom_grupo_estadistico3, da.nom_grupo_estadistico4,
      da.nom_subdireccion, da.nom_gerencia, da.nom_zona, da.nom_cliente, da.zona, da.nom_estado, da.nom_canal
      ORDER BY da.semana
      )
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

  set: filtros {
    fields: [nom_cliente, zona, nom_estado, nom_canal, nom_subdireccion, nom_gerencia, nom_zona, nom_grupo_estadistico1, nom_grupo_estadistico2, nom_grupo_estadistico3, nom_grupo_estadistico4]

  }

  set: detail {
    fields: [
      semana,
      semana_label,
      mes,
      anio,
      trimestre,
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

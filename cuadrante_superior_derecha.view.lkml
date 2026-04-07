view: cuadrante_superior_derecha {
  derived_table: {
    sql:
      -- =====================================================
      -- QUERY PARA CUADRANTE SUPERIOR DERECHO
      -- Bubble Chart: Indice Precio vs Spread por Semana
      -- =====================================================

      WITH
      -- Últimas 6 semanas con datos reales; filtro 90 días para partition pruning
      semanas_disponibles AS (
        SELECT DISTINCT anio_semana AS semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        WHERE fecha IS NOT NULL
          AND fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
          AND fecha <= CURRENT_DATE()
          AND anio_semana IS NOT NULL
        ORDER BY anio_semana DESC
        LIMIT 6
      ),
      -- nom_cliente, zona, nom_estado, nom_canal se mantienen en todo el recorrido (datos_base → datos_con_indice → datos_agregados → SELECT final) para filtros en tiles
      datos_base AS (
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
          SAFE_CAST(v.spread AS FLOAT64) AS spread,
          SAFE_CAST(v.costo_mp AS FLOAT64) AS costo_mp,
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
          SAFE_CAST(v.precio_pulso AS FLOAT64) AS precio_pulso,
          SAFE_CAST(v.toneladas_facturadas AS FLOAT64) AS toneladas_facturadas,
          SAFE_CAST(v.imp_facturado_exworks_mn AS FLOAT64) AS imp_facturado_exworks_mn
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
        WHERE v.anio_semana IS NOT NULL
          AND v.fecha IS NOT NULL
          AND v.anio_semana IN (SELECT semana FROM semanas_disponibles)
          AND (
            v.spread IS NOT NULL
            OR (
              SAFE_CAST(v.toneladas_pedidas AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(v.toneladas_pedidas AS FLOAT64) != 0
              AND SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) IS NOT NULL
              AND SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) IS NOT NULL
            )
            OR v.toneladas_facturadas IS NOT NULL
            OR v.precio_pulso IS NOT NULL
          )
      ),

      datos_con_indice AS (
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
          MIN(fecha_contable) AS fecha_contable_min,
          MAX(fecha_contable) AS fecha_contable_max,
          -- Promedio de Spread (solo valores no nulos)
          AVG(spread) AS spread_promedio,
          -- Promedio de Indice Precio (solo valores no nulos)
          AVG(indice_precio) AS indice_precio_promedio,
          -- Suma de toneladas para tamaño de burbuja
          SUM(COALESCE(toneladas_facturadas, 0)) AS toneladas_totales,
          -- Estadísticas adicionales para validación
          COUNT(*) AS registros,
          COUNT(DISTINCT fecha_contable) AS dias_distintos,
          -- Contar cuántos registros tienen cada valor para debugging
          COUNT(indice_precio) AS registros_con_indice,
          COUNT(spread) AS registros_con_spread
        FROM datos_con_indice
        WHERE (indice_precio IS NOT NULL OR spread IS NOT NULL)
        GROUP BY semana, nom_grupo_estadistico1, nom_grupo_estadistico2, nom_grupo_estadistico3, nom_grupo_estadistico4, nom_subdireccion, nom_gerencia, nom_zona, nom_cliente, zona, nom_estado, nom_canal
        HAVING (AVG(indice_precio) IS NOT NULL
           OR AVG(spread) IS NOT NULL)
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
      WHERE (indice_precio_promedio IS NOT NULL
        OR spread_promedio IS NOT NULL)
      ORDER BY semana DESC ;;
  }

  # ============================================
  # DIMENSIONS (Campos para agrupar/filtrar)
  # ============================================

  dimension: semana_sort {
    type: number
    sql: CAST(${TABLE}.semana AS INT64) ;;
    hidden: yes
    description: "Campo numérico oculto para ordenar semanas correctamente"
  }

  dimension: semana {
    type: string
    sql: ${TABLE}.semana ;;
    description: "Semana en formato YYYYWW"
    order_by_field: semana_sort
  }

  dimension: semana_label {
    type: string
    sql: ${TABLE}.semana_label ;;
    description: "Etiqueta de semana formateada (ej: S45)"
    order_by_field: semana_sort
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
    order_by_field: mes
    suggest_explore: ven_mart_comercial_periodos
    suggest_dimension: ven_mart_comercial_periodos.nombre_periodo_mostrar
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
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_grupo_estadistico1
  }

  dimension: nom_grupo_estadistico2 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico2 ;;
    description: "Nom Grupo Estadistico 2"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_grupo_estadistico2
  }

  dimension: nom_grupo_estadistico3 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico3 ;;
    description: "Nom Grupo Estadistico 3"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_grupo_estadistico3
  }

  dimension: nom_grupo_estadistico4 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico4 ;;
    description: "Nom Grupo Estadistico 4"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_grupo_estadistico4
  }

  dimension: nom_subdireccion {
    type: string
    sql: ${TABLE}.nom_subdireccion ;;
    description: "Nom Subdireccion"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_subdireccion
  }

  dimension: nom_gerencia {
    type: string
    sql: ${TABLE}.nom_gerencia ;;
    description: "Nom Gerencia"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_gerencia
  }

  dimension: nom_zona {
    type: string
    sql: ${TABLE}.nom_zona ;;
    description: "Nom Zona"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_zona
  }

  dimension: nom_cliente {
    type: string
    sql: ${TABLE}.nom_cliente ;;
    description: "Nombre cliente"
    group_item_label: "Filtros"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_cliente
  }

  dimension: zona {
    type: string
    sql: ${TABLE}.zona ;;
    description: "Zona"
    group_item_label: "Filtros"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.zona
  }

  dimension: nom_estado {
    type: string
    sql: ${TABLE}.nom_estado ;;
    description: "Nombre estado"
    group_item_label: "Filtros"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_estado
  }

  dimension: nom_canal {
    type: string
    sql: ${TABLE}.nom_canal ;;
    description: "Nombre canal"
    group_item_label: "Filtros"
    suggest_explore: ven_mart_comercial
    suggest_dimension: ven_mart_comercial.nom_canal
  }

  # ============================================
  # MEASURES (Valores numéricos calculables)
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  measure: indice_precio {
    type: max
    sql: ${TABLE}.indice_precio ;;
    value_format_name: decimal_4
    description: "Índice de precio (precio_caida / pulso)"
  }

  measure: spread {
    type: max
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
      indice_precio,
      spread,
      toneladas_facturadas,
      registros,
      dias_distintos
    ]
  }
}

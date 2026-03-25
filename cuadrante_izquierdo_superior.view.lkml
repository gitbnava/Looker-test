view: cuadrante_izquierdo_superior {
  derived_table: {
    sql:
      -- Optimizado: filtro 90 días, una sola pasada UNNEST en lugar de 9 UNION ALL
      WITH
      semana_actual_calculada AS (
        SELECT
          CAST(EXTRACT(YEAR FROM CURRENT_DATE()) AS STRING) ||
          LPAD(CAST(EXTRACT(ISOWEEK FROM CURRENT_DATE()) AS STRING), 2, '0') AS semana_actual_str
      ),
      -- Solo últimas 5 semanas; restringir a 90 días para reducir bytes escaneados (partition pruning)
      semanas_disponibles AS (
        SELECT DISTINCT anio_semana AS semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        CROSS JOIN semana_actual_calculada
        WHERE fecha IS NOT NULL
          AND fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
          AND fecha <= CURRENT_DATE()
          AND Tipo_Cambio IS NOT NULL
          AND SAFE_CAST(Tipo_Cambio AS FLOAT64) > 0
          AND anio_semana IS NOT NULL
          AND anio_semana <= (SELECT semana_actual_str FROM semana_actual_calculada)
          AND (
            (SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) IS NOT NULL AND SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) > 0)
            OR (SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) IS NOT NULL AND SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) > 0)
            OR (SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) IS NOT NULL AND SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) > 0)
            OR (SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) IS NOT NULL AND SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) > 0)
            OR (SAFE_CAST(Angulo_Comercial_China AS FLOAT64) IS NOT NULL AND SAFE_CAST(Angulo_Comercial_China AS FLOAT64) > 0)
            OR (SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) IS NOT NULL AND SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) > 0)
            OR (SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) IS NOT NULL AND SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) > 0)
            OR (SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) IS NOT NULL AND SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) > 0)
            OR (SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) IS NOT NULL AND SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) > 0)
          )
        ORDER BY anio_semana DESC
        LIMIT 6
      ),
      semana_limite AS (
        SELECT MIN(semana) AS semana_limite_str FROM semanas_disponibles
      ),
      -- Precios de importación agregados por semana (de cualquier fila con esos campos)
      -- Desacoplado de GE para que funcione con cualquier filtro de producto
      ref_por_semana AS (
        SELECT
          anio_semana AS semana,
          AVG(SAFE_CAST(Tipo_Cambio AS FLOAT64)) AS Tipo_Cambio,
          AVG(CASE WHEN SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) END) AS precio_usd_turkey_rebar,
          AVG(CASE WHEN SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) > 0 THEN SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) END) AS precio_usd_spain_rebar,
          AVG(CASE WHEN SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) > 0 THEN SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) END) AS precio_usd_malasia_varilla,
          AVG(CASE WHEN SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) END) AS precio_usd_turkey_angulo,
          AVG(CASE WHEN SAFE_CAST(Angulo_Comercial_China AS FLOAT64) > 0 THEN SAFE_CAST(Angulo_Comercial_China AS FLOAT64) END) AS precio_usd_china_angulo,
          AVG(CASE WHEN SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) END) AS precio_usd_turkey_vigas,
          AVG(CASE WHEN SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) > 0 THEN SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) END) AS precio_usd_pulso_vigas,
          AVG(CASE WHEN SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) > 0 THEN SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) END) AS precio_usd_amm_europa,
          AVG(CASE WHEN SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) > 0 THEN SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) END) AS precio_usd_amm_asia,
          MAX(Pais_Origen_Pulso_Vigas) AS Pais_Origen_Pulso_Vigas
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        WHERE anio_semana IN (SELECT semana FROM semanas_disponibles)
          AND SAFE_CAST(Tipo_Cambio AS FLOAT64) > 0
        GROUP BY anio_semana
      ),
      -- Todos los registros de las semanas disponibles, sin filtrar por Tipo_Cambio
      -- Los precios de importación se obtienen del CTE semanal vía JOIN
      precios_internacionales AS (
        SELECT
          v.fecha AS fecha_contable,
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
          r.Tipo_Cambio,
          -- precio_caida_pedidos: precio por tonelada ($/ton) = imp_precio_entrega_mn / toneladas_caida_de_pedidos
          CASE
            WHEN SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) > 0
              AND SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) > 0
            THEN SAFE_DIVIDE(
              SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64),
              SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
            )
            ELSE NULL
          END AS precio_caida_pedidos,
          SAFE_CAST(v.precio_pulso AS FLOAT64) AS precio_pulso,
          r.precio_usd_turkey_rebar,
          r.precio_usd_spain_rebar,
          r.precio_usd_malasia_varilla,
          r.precio_usd_turkey_angulo,
          r.precio_usd_china_angulo,
          r.precio_usd_turkey_vigas,
          r.precio_usd_pulso_vigas,
          r.precio_usd_amm_europa,
          r.precio_usd_amm_asia,
          r.Pais_Origen_Pulso_Vigas
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` v
        INNER JOIN ref_por_semana r ON v.anio_semana = r.semana
        WHERE v.fecha IS NOT NULL
          AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
          AND v.anio_semana IN (SELECT semana FROM semanas_disponibles)
      ),
      -- Una sola pasada con UNNEST en lugar de 9 UNION ALL (menos lecturas del CTE, menos shuffle)
      precios_unificados AS (
        SELECT
          p.fecha_contable,
          p.semana,
          p.mes,
          p.anio,
          p.trimestre,
          p.nombre_periodo_mostrar,
          p.nom_grupo_estadistico1,
          p.nom_grupo_estadistico2,
          p.nom_grupo_estadistico3,
          p.nom_grupo_estadistico4,
          p.nom_subdireccion,
          p.nom_gerencia,
          p.nom_zona,
          p.nom_cliente,
          p.zona,
          p.nom_estado,
          p.nom_canal,
          p.Tipo_Cambio,
          p.precio_caida_pedidos,
          p.precio_pulso,
          ref.referencia_nombre,
          ref.pais,
          ref.producto_tipo,
          ref.precio_usd,
          CASE WHEN p.Tipo_Cambio IS NOT NULL AND ref.precio_usd IS NOT NULL
            THEN p.Tipo_Cambio * ref.precio_usd ELSE NULL END AS precio_mxn
        FROM precios_internacionales p
        CROSS JOIN UNNEST([
          STRUCT('Turkey - Rebar FOB' AS referencia_nombre, 'Turkey' AS pais, 'Rebar' AS producto_tipo, p.precio_usd_turkey_rebar AS precio_usd),
          STRUCT('Spain - Rebar FOB' AS referencia_nombre, 'Spain' AS pais, 'Rebar' AS producto_tipo, p.precio_usd_spain_rebar AS precio_usd),
          STRUCT('Malasia - Varilla' AS referencia_nombre, 'Malasia' AS pais, 'Varilla' AS producto_tipo, p.precio_usd_malasia_varilla AS precio_usd),
          STRUCT('Turkey - Ángulo Comercial' AS referencia_nombre, 'Turkey' AS pais, 'Ángulo' AS producto_tipo, p.precio_usd_turkey_angulo AS precio_usd),
          STRUCT('China - Ángulo Comercial' AS referencia_nombre, 'China' AS pais, 'Ángulo' AS producto_tipo, p.precio_usd_china_angulo AS precio_usd),
          STRUCT('Turkey - Vigas IPN' AS referencia_nombre, 'Turkey' AS pais, 'Vigas IPN' AS producto_tipo, p.precio_usd_turkey_vigas AS precio_usd),
          STRUCT(CONCAT(IFNULL(p.Pais_Origen_Pulso_Vigas, 'Desconocido'), ' - Pulso Vigas') AS referencia_nombre, IFNULL(p.Pais_Origen_Pulso_Vigas, 'Desconocido') AS pais, 'Pulso Vigas' AS producto_tipo, p.precio_usd_pulso_vigas AS precio_usd),
          STRUCT('Sur Europa - Índice AMM' AS referencia_nombre, 'Sur Europa' AS pais, 'Índice AMM' AS producto_tipo, p.precio_usd_amm_europa AS precio_usd),
          STRUCT('Sudeste Asiático - Índice AMM' AS referencia_nombre, 'Sudeste Asiático' AS pais, 'Índice AMM' AS producto_tipo, p.precio_usd_amm_asia AS precio_usd)
        ]) AS ref
        WHERE ref.precio_usd IS NOT NULL AND ref.precio_usd > 0
      ),

      precios_con_calculos AS (
      SELECT
      fecha_contable,
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
      referencia_nombre,
      pais,
      producto_tipo,
      precio_usd,
      precio_mxn,
      Tipo_Cambio,
      precio_caida_pedidos AS precio_caida_mxn,
      precio_pulso,
      LAG(precio_mxn) OVER (PARTITION BY referencia_nombre ORDER BY semana DESC, fecha_contable DESC) AS precio_semana_anterior,
      SAFE_DIVIDE(precio_caida_pedidos, precio_pulso) AS indice_precio
      FROM precios_unificados
      WHERE precio_mxn IS NOT NULL
      AND precio_mxn > 0
      )

      SELECT
      referencia_nombre,
      pais,
      producto_tipo,
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
      precio_usd,
      precio_mxn AS precio_nov,
      precio_caida_mxn,
      ROUND(SAFE_DIVIDE((precio_mxn - precio_semana_anterior), precio_semana_anterior) * 100, 2) AS caida_porcentual,
      ROUND(SAFE_DIVIDE((precio_caida_mxn - precio_mxn), precio_mxn) * 100, 2) AS senal_porcentual,
      indice_precio,
      Tipo_Cambio,
      precio_pulso
      FROM precios_con_calculos ;;
  }

  # ============================================
  # DIMENSIONS (Campos para agrupar/filtrar)
  # ============================================

  dimension: referencia_nombre {
    type: string
    sql: ${TABLE}.referencia_nombre ;;
    description: "Nombre de la referencia de precio internacional"
  }

  dimension: pais {
    type: string
    sql: ${TABLE}.pais ;;
    description: "País de origen del precio de referencia"
  }

  dimension: producto_tipo {
    type: string
    sql: ${TABLE}.producto_tipo ;;
    description: "Tipo de producto (Rebar, Varilla, Ángulo, etc.)"
  }

  dimension: semana {
    type: string
    sql: ${TABLE}.semana ;;
    description: "Semana en formato YYYYWW"
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
    description: "Trimestre (ej: Trim 1, Trim 2, etc.)"
  }

  dimension: nombre_periodo_mostrar {
    type: string
    sql: ${TABLE}.nombre_periodo_mostrar ;;
    description: "Período formateado para mostrar (ej: Nov-2025)"
  }

  dimension: fecha_contable {
    type: date
    datatype: date
    sql: ${TABLE}.fecha_contable ;;
    description: "Fecha contable"
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

  measure: precio_usd {
    type: average
    sql: ${TABLE}.precio_usd ;;
    value_format_name: usd
    description: "Precio en USD"
  }

  measure: precio_nov {
    type: average
    sql: ${TABLE}.precio_nov ;;
    value_format_name: usd
    description: "Precio del período en MXN"
  }

  measure: precio_caida_mxn {
    type: average
    sql: ${TABLE}.precio_caida_mxn ;;
    value_format_name: usd
    description: "Precio caída en MXN"
  }

  measure: caida_porcentual {
    type: average
    sql: ${TABLE}.caida_porcentual ;;
    value_format_name: decimal_2
    description: "Variación porcentual vs período anterior (%)"
  }

  measure: senal_porcentual {
    type: average
    sql: ${TABLE}.senal_porcentual ;;
    value_format_name: decimal_2
    description: "Señal porcentual calculada (%)"
  }

  measure: indice_precio {
    type: average
    sql: ${TABLE}.indice_precio ;;
    value_format_name: decimal_4
    description: "Índice de precio (precio_caida / pulso)"
  }

  measure: tipo_cambio {
    type: average
    sql: ${TABLE}.Tipo_Cambio ;;
    value_format_name: decimal_2
    description: "Tipo de cambio usado para conversión"
  }

  measure: precio_pulso {
    type: average
    sql: ${TABLE}.precio_pulso ;;
    value_format_name: usd
    description: "Precio pulso en MXN"
  }

  measure: precio_pulso_min {
    type: min
    sql: ${TABLE}.precio_pulso ;;
    value_format_name: usd
    description: "Precio pulso mínimo en MXN"
  }

  # ============================================
  # SETS (Agrupaciones de campos)
  # ============================================

  set: filtros {
    fields: [nom_cliente, zona, nom_estado, nom_canal, nom_subdireccion, nom_gerencia, nom_zona, nom_grupo_estadistico1, nom_grupo_estadistico2, nom_grupo_estadistico3, nom_grupo_estadistico4]

  }

  set: detail {
    fields: [
      referencia_nombre,
      pais,
      producto_tipo,
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
      precio_usd,
      precio_nov,
      precio_caida_mxn,
      caida_porcentual,
      senal_porcentual,
      indice_precio,
      tipo_cambio,
      precio_pulso,
      precio_pulso_min
    ]
  }
}

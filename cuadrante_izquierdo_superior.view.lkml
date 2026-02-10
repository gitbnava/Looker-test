view: cuadrante_izquierdo_superior {
  derived_table: {
    sql:
      WITH
      -- Encontrar la semana máxima disponible en los datos y calcular límite (últimas 6 semanas)
      -- Filtrar solo semanas hasta la fecha actual para evitar semanas futuras
      semana_actual_calculada AS (
        SELECT
          CAST(EXTRACT(YEAR FROM CURRENT_DATE()) AS STRING) ||
          LPAD(CAST(EXTRACT(ISOWEEK FROM CURRENT_DATE()) AS STRING), 2, '0') AS semana_actual_str
      ),
      semanas_disponibles AS (
        SELECT DISTINCT semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        CROSS JOIN semana_actual_calculada
        WHERE fecha_contable IS NOT NULL
          AND Tipo_Cambio IS NOT NULL
          AND semana IS NOT NULL
          AND semana <= (SELECT semana_actual_str FROM semana_actual_calculada)
          AND fecha_contable <= CURRENT_DATE()
        ORDER BY semana DESC
        LIMIT 6
      ),

      semana_limite AS (
        SELECT MIN(semana) AS semana_limite_str
        FROM semanas_disponibles
      ),

      precios_internacionales AS (
        SELECT
          fecha_contable,
          semana,
          mes,
          anio,
          trimestre,
          nombre_periodo_mostrar,
          SAFE_CAST(Tipo_Cambio AS FLOAT64) AS Tipo_Cambio,
          SAFE_CAST(precio_caida_pedidos AS FLOAT64) AS precio_caida_pedidos,
          SAFE_CAST(precio_pulso AS FLOAT64) AS precio_pulso,
          SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) AS precio_usd_turkey_rebar,
          SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) AS precio_usd_spain_rebar,
          SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) AS precio_usd_malasia_varilla,
          SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) AS precio_usd_turkey_angulo,
          SAFE_CAST(Angulo_Comercial_China AS FLOAT64) AS precio_usd_china_angulo,
          SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) AS precio_usd_turkey_vigas,
          SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) AS precio_usd_pulso_vigas,
          SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) AS precio_usd_amm_europa,
          SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) AS precio_usd_amm_asia,
          Pais_Origen_Pulso_Vigas
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        CROSS JOIN semana_limite
        WHERE fecha_contable IS NOT NULL
          AND Tipo_Cambio IS NOT NULL
          AND semana >= (SELECT semana_limite_str FROM semana_limite)
          AND (
            Rebar_FOB_Turkey IS NOT NULL
            OR Rebar_FOB_Spain IS NOT NULL
            OR Precio_Varilla_Malasia IS NOT NULL
            OR Angulo_Comercial_Turkey IS NOT NULL
            OR Angulo_Comercial_China IS NOT NULL
            OR Vigas_IPN_Turkey IS NOT NULL
            OR Pulso_Vigas_Int IS NOT NULL
            OR Indice_AMM_Sur_Europa IS NOT NULL
            OR indice_AMM_Sudeste_Asiatico IS NOT NULL
          )
      ),

      precios_unificados AS (
        SELECT
          fecha_contable,
          semana,
          mes,
          anio,
          trimestre,
          nombre_periodo_mostrar,
          Tipo_Cambio,
          precio_caida_pedidos,
          precio_pulso,
          'Turkey - Rebar FOB' AS referencia_nombre,
          'Turkey' AS pais,
          'Rebar' AS producto_tipo,
          precio_usd_turkey_rebar AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_turkey_rebar IS NOT NULL
            THEN Tipo_Cambio * precio_usd_turkey_rebar ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_turkey_rebar IS NOT NULL
          AND precio_usd_turkey_rebar > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          'Spain - Rebar FOB' AS referencia_nombre,
          'Spain' AS pais, 'Rebar' AS producto_tipo,
          precio_usd_spain_rebar AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_spain_rebar IS NOT NULL
            THEN Tipo_Cambio * precio_usd_spain_rebar ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_spain_rebar IS NOT NULL
          AND precio_usd_spain_rebar > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          'Malasia - Varilla' AS referencia_nombre,
          'Malasia' AS pais, 'Varilla' AS producto_tipo,
          precio_usd_malasia_varilla AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_malasia_varilla IS NOT NULL
            THEN Tipo_Cambio * precio_usd_malasia_varilla ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_malasia_varilla IS NOT NULL
          AND precio_usd_malasia_varilla > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          'Turkey - Ángulo Comercial' AS referencia_nombre,
          'Turkey' AS pais, 'Ángulo' AS producto_tipo,
          precio_usd_turkey_angulo AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_turkey_angulo IS NOT NULL
            THEN Tipo_Cambio * precio_usd_turkey_angulo ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_turkey_angulo IS NOT NULL
          AND precio_usd_turkey_angulo > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          'China - Ángulo Comercial' AS referencia_nombre,
          'China' AS pais, 'Ángulo' AS producto_tipo,
          precio_usd_china_angulo AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_china_angulo IS NOT NULL
            THEN Tipo_Cambio * precio_usd_china_angulo ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_china_angulo IS NOT NULL
          AND precio_usd_china_angulo > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          'Turkey - Vigas IPN' AS referencia_nombre,
          'Turkey' AS pais, 'Vigas IPN' AS producto_tipo,
          precio_usd_turkey_vigas AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_turkey_vigas IS NOT NULL
            THEN Tipo_Cambio * precio_usd_turkey_vigas ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_turkey_vigas IS NOT NULL
          AND precio_usd_turkey_vigas > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          CONCAT(IFNULL(Pais_Origen_Pulso_Vigas, 'Desconocido'), ' - Pulso Vigas') AS referencia_nombre,
          IFNULL(Pais_Origen_Pulso_Vigas, 'Desconocido') AS pais,
          'Pulso Vigas' AS producto_tipo,
          precio_usd_pulso_vigas AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_pulso_vigas IS NOT NULL
            THEN Tipo_Cambio * precio_usd_pulso_vigas ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_pulso_vigas IS NOT NULL
          AND precio_usd_pulso_vigas > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          'Sur Europa - Índice AMM' AS referencia_nombre,
          'Sur Europa' AS pais, 'Índice AMM' AS producto_tipo,
          precio_usd_amm_europa AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_amm_europa IS NOT NULL
            THEN Tipo_Cambio * precio_usd_amm_europa ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_amm_europa IS NOT NULL
          AND precio_usd_amm_europa > 0

        UNION ALL

        SELECT
          fecha_contable, semana, mes, anio, trimestre, nombre_periodo_mostrar,
          Tipo_Cambio, precio_caida_pedidos, precio_pulso,
          'Sudeste Asiático - Índice AMM' AS referencia_nombre,
          'Sudeste Asiático' AS pais, 'Índice AMM' AS producto_tipo,
          precio_usd_amm_asia AS precio_usd,
          CASE WHEN Tipo_Cambio IS NOT NULL AND precio_usd_amm_asia IS NOT NULL
            THEN Tipo_Cambio * precio_usd_amm_asia ELSE NULL END AS precio_mxn
        FROM precios_internacionales
        WHERE precio_usd_amm_asia IS NOT NULL
          AND precio_usd_amm_asia > 0
      ),

      precios_con_calculos AS (
        SELECT
          fecha_contable,
          semana,
          mes,
          anio,
          trimestre,
          nombre_periodo_mostrar,
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

  # ============================================
  # MEASURES (Valores numéricos calculables)
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  measure: precio_usd {
    type: sum
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
    type: sum
    sql: ${TABLE}.indice_precio ;;
    value_format_name: decimal_4
    description: "Índice de precio (precio_caida / pulso)"
  }

  measure: tipo_cambio {
    type: sum
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

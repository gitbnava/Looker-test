view: cuadrante_izquierdo_superior {
  derived_table: {
    sql:
      -- Optimizado: filtro 90 días, una sola pasada UNNEST en lugar de 9 UNION ALL
      -- Alineado a definiciones D5, D9, D11 y KPIs #1, #2-23
      WITH
      -- Últimas 6 semanas con datos reales; filtro 90 días para partition pruning
      -- Bloque transaccional del mart (control IN (1, 6)):
      --   control=1: transacciones facturación/entrega principales (~145k filas/90d, con TC, tons_caida, imp_entrega)
      --   control=6: flujos complementarios con imp_entrega capturado (~41k filas/90d, con TC e imp_entrega)
      -- Excluidos por diagnóstico BigQuery:
      --   control=101: mayor volumen pero sin tons_caida ni imp_entrega
      --   control=103: bloque finanzas (sin campos transaccionales)
      --   control=8: plantilla maestra/datos atípicos sin TC ni imp_entrega reales
      semanas_disponibles AS (
        SELECT DISTINCT anio_semana AS semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        WHERE fecha IS NOT NULL
          AND fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
          AND fecha <= CURRENT_DATE()
          AND anio_semana IS NOT NULL
          AND control IN (1, 6)
        ORDER BY anio_semana DESC
        LIMIT 6
      ),
      -- Precios de importación agregados por semana (de cualquier fila con esos campos)
      -- Desacoplado de GE para que funcione con cualquier filtro de producto
      -- Fuente Tipo_Cambio: mart comercial (diario).
      -- D11 documenta adicionalmente una fuente semanal en Google Sheets para la sección
      -- de precios internacionales. Aquí se usa el TC del mart por disponibilidad en BigQuery
      -- y por consistencia con las transacciones. Si se requiere TC semanal oficial para
      -- importaciones, debe integrarse la fuente externa como CTE adicional.
      ref_por_semana AS (
        SELECT
          anio_semana AS semana,
          AVG(CASE WHEN SAFE_CAST(Tipo_Cambio AS FLOAT64) > 5 THEN SAFE_CAST(Tipo_Cambio AS FLOAT64) END) AS Tipo_Cambio,
          AVG(CASE WHEN SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Rebar_FOB_Turkey AS FLOAT64) END) AS precio_usd_turkey_rebar,
          AVG(CASE WHEN SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) > 0 THEN SAFE_CAST(Rebar_FOB_Spain AS FLOAT64) END) AS precio_usd_spain_rebar,
          AVG(CASE WHEN SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) > 0 THEN SAFE_CAST(Precio_Varilla_Malasia AS FLOAT64) END) AS precio_usd_malasia_varilla,
          AVG(CASE WHEN SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Angulo_Comercial_Turkey AS FLOAT64) END) AS precio_usd_turkey_angulo,
          AVG(CASE WHEN SAFE_CAST(Angulo_Comercial_China AS FLOAT64) > 0 THEN SAFE_CAST(Angulo_Comercial_China AS FLOAT64) END) AS precio_usd_china_angulo,
          AVG(CASE WHEN SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) > 0 THEN SAFE_CAST(Vigas_IPN_Turkey AS FLOAT64) END) AS precio_usd_turkey_vigas,
          AVG(CASE WHEN SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) > 0 THEN SAFE_CAST(Pulso_Vigas_Int AS FLOAT64) END) AS precio_usd_pulso_vigas,
          AVG(CASE WHEN SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) > 0 THEN SAFE_CAST(Indice_AMM_Sur_Europa AS FLOAT64) END) AS precio_usd_amm_europa,
          AVG(CASE WHEN SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) > 0 THEN SAFE_CAST(indice_AMM_Sudeste_Asiatico AS FLOAT64) END) AS precio_usd_amm_asia,
          -- Señales de precio por grupo estadístico (KPI #1 / D5)
          AVG(CASE WHEN SAFE_CAST(Senal_Varilla AS FLOAT64) > 0 THEN SAFE_CAST(Senal_Varilla AS FLOAT64) END) AS senal_varilla,
          AVG(CASE WHEN SAFE_CAST(Senal_Alambron AS FLOAT64) > 0 THEN SAFE_CAST(Senal_Alambron AS FLOAT64) END) AS senal_alambron,
          AVG(CASE WHEN SAFE_CAST(Senal_Angulos_AAA AS FLOAT64) > 0 THEN SAFE_CAST(Senal_Angulos_AAA AS FLOAT64) END) AS senal_angulos_aaa,
          -- Precios CIF de llegada y premiums de importación (KPIs #4-7 / D4)
          -- precio_importacion_llegada = CIF + aranceles (tablas prem_var/prem_alam/prem_perf)
          -- premium_importacion = premium sobre precio de llegada
          AVG(CASE WHEN SAFE_CAST(precio_importacion_llegada1 AS FLOAT64) > 0 THEN SAFE_CAST(precio_importacion_llegada1 AS FLOAT64) END) AS precio_importacion_llegada1,
          AVG(CASE WHEN SAFE_CAST(precio_importacion_llegada2 AS FLOAT64) > 0 THEN SAFE_CAST(precio_importacion_llegada2 AS FLOAT64) END) AS precio_importacion_llegada2,
          AVG(CASE WHEN SAFE_CAST(premium_importacion1 AS FLOAT64) IS NOT NULL THEN SAFE_CAST(premium_importacion1 AS FLOAT64) END) AS premium_importacion1,
          AVG(CASE WHEN SAFE_CAST(premium_importacion2 AS FLOAT64) IS NOT NULL THEN SAFE_CAST(premium_importacion2 AS FLOAT64) END) AS premium_importacion2,
          MAX(Pais_Origen_Pulso_Vigas) AS Pais_Origen_Pulso_Vigas
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        WHERE anio_semana IN (SELECT semana FROM semanas_disponibles)
          AND SAFE_CAST(Tipo_Cambio AS FLOAT64) > 0
          AND control IN (1, 6)  -- bloque transaccional (ver comentario en semanas_disponibles)
        GROUP BY anio_semana
      ),
      -- Todos los registros de las semanas disponibles, sin filtrar por Tipo_Cambio
      -- Los precios de importación se obtienen del CTE semanal vía JOIN
      -- precio_caida_pedidos alineado a D9: imp caída / toneladas_caida_de_pedidos
      -- precio_senial_calculado alineado a KPI #1: CASE por grupo estadístico
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
          -- precio_caida_pedidos: precio por tonelada de pedidos caídos ($/ton) según D9
          -- Fórmula: imp_precio_entrega_mn / toneladas_caida_de_pedidos
          -- Mínimo 1 tonelada para evitar outliers por denominadores casi-cero
          CASE
            WHEN SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) >= 1
              AND SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) > 0
            THEN SAFE_DIVIDE(
              SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64),
              SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
            )
            ELSE NULL
          END AS precio_caida_pedidos,
          -- precio_senial_calculado: señal de precio por grupo estadístico (KPI #1 / D5)
          -- CASE: VARILLA->Senal_Varilla; ALAMBRON->Senal_Alambron; ALAMBRON CONST->Senal_Varilla+200;
          --       PERFILES->Senal_Angulos_AAA
          -- Regla validada con funcional: ALAMBRON CONST = Senal_Varilla + 200 MXN/ton (KPI #1).
          -- Fuente: kpis_sin_documentar.csv y Diccionario_Actualizado.md L135.
          CASE
            WHEN UPPER(v.nom_grupo_estadistico1) = 'VARILLA' THEN r.senal_varilla
            WHEN UPPER(v.nom_grupo_estadistico1) = 'ALAMBRON CONST' THEN r.senal_varilla + 200
            WHEN UPPER(v.nom_grupo_estadistico1) = 'ALAMBRON' THEN r.senal_alambron
            WHEN UPPER(v.nom_grupo_estadistico1) = 'PERFILES' THEN r.senal_angulos_aaa
            ELSE NULL
          END AS precio_senial_calculado,
          -- Importe señal ponderable (precio_senial * toneladas_caida) según KPI #1
          CASE
            WHEN SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) >= 1
              AND (
                (UPPER(v.nom_grupo_estadistico1) = 'VARILLA' AND r.senal_varilla IS NOT NULL)
                OR (UPPER(v.nom_grupo_estadistico1) = 'ALAMBRON CONST' AND r.senal_varilla IS NOT NULL)
                OR (UPPER(v.nom_grupo_estadistico1) = 'ALAMBRON' AND r.senal_alambron IS NOT NULL)
                OR (UPPER(v.nom_grupo_estadistico1) = 'PERFILES' AND r.senal_angulos_aaa IS NOT NULL)
              )
            THEN
              CASE
                WHEN UPPER(v.nom_grupo_estadistico1) = 'VARILLA' THEN r.senal_varilla * SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
                WHEN UPPER(v.nom_grupo_estadistico1) = 'ALAMBRON CONST' THEN (r.senal_varilla + 200) * SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
                WHEN UPPER(v.nom_grupo_estadistico1) = 'ALAMBRON' THEN r.senal_alambron * SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
                WHEN UPPER(v.nom_grupo_estadistico1) = 'PERFILES' THEN r.senal_angulos_aaa * SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
              END
            ELSE NULL
          END AS importe_senial_ponderado,
          SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) AS toneladas_caida_de_pedidos,
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
          -- Precios CIF de llegada y premiums (KPIs #4-7 / D4)
          r.precio_importacion_llegada1,
          r.precio_importacion_llegada2,
          r.premium_importacion1,
          r.premium_importacion2,
          r.Pais_Origen_Pulso_Vigas
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` v
        -- LEFT JOIN permite preservar filas transaccionales aunque ref_por_semana no tenga
        -- Tipo_Cambio para la semana. precio_mxn será NULL pero precio_caida_pedidos se preserva.
        LEFT JOIN ref_por_semana r ON v.anio_semana = r.semana
        WHERE v.fecha IS NOT NULL
          AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
          AND v.anio_semana IN (SELECT semana FROM semanas_disponibles)
          AND v.control IN (1, 6)  -- bloque transaccional (ver comentario en semanas_disponibles)
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
          p.precio_senial_calculado,
          p.importe_senial_ponderado,
          p.toneladas_caida_de_pedidos,
          p.precio_pulso,
          p.precio_importacion_llegada1,
          p.precio_importacion_llegada2,
          p.premium_importacion1,
          p.premium_importacion2,
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
      precio_senial_calculado,
      importe_senial_ponderado,
      toneladas_caida_de_pedidos,
      precio_pulso,
      precio_importacion_llegada1,
      precio_importacion_llegada2,
      premium_importacion1,
      premium_importacion2,
      LAG(precio_mxn) OVER (PARTITION BY referencia_nombre ORDER BY semana ASC, fecha_contable ASC) AS precio_importacion_semana_anterior,
      LAG(precio_caida_pedidos) OVER (PARTITION BY referencia_nombre ORDER BY semana ASC, fecha_contable ASC) AS precio_caida_semana_anterior,
      -- indice_precio: relación precio caída / pulso.
      -- Métrica derivada construida en este LookML como apoyo visual del cuadrante.
      -- No aparece explícitamente en el catálogo oficial (kpis_sin_documentar.csv, D1-D19),
      -- por lo que se mantiene como complementaria. Uso: >1 indica precio caída por encima del pulso.
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
      precio_mxn AS precio_importacion_mxn,
      precio_caida_mxn,
      precio_senial_calculado,
      importe_senial_ponderado,
      toneladas_caida_de_pedidos,
      -- Variación porcentual semanal del precio de importación en MXN
      ROUND(SAFE_DIVIDE((precio_mxn - precio_importacion_semana_anterior), precio_importacion_semana_anterior) * 100, 2) AS variacion_importacion_pct,
      -- Variación porcentual semanal del precio de caída (D9)
      ROUND(SAFE_DIVIDE((precio_caida_mxn - precio_caida_semana_anterior), precio_caida_semana_anterior) * 100, 2) AS variacion_caida_pct,
      -- Señal porcentual: desvío entre precio de caída real vs precio señal objetivo (D5 / KPI #1)
      ROUND(SAFE_DIVIDE((precio_caida_mxn - precio_senial_calculado), precio_senial_calculado) * 100, 2) AS senal_porcentual,
      indice_precio,
      Tipo_Cambio,
      precio_pulso,
      -- Precios CIF de llegada y premiums (KPIs #4-7 / D4)
      precio_importacion_llegada1,
      precio_importacion_llegada2,
      premium_importacion1,
      premium_importacion2
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
    order_by_field: mes
    suggest_explore: ven_mart_comercial_periodos
    suggest_dimension: ven_mart_comercial_periodos.nombre_periodo_mostrar
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
  }

  dimension: nom_grupo_estadistico2 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico2 ;;
    description: "Nom Grupo Estadistico 2"
  }

  dimension: nom_grupo_estadistico3 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico3 ;;
    description: "Nom Grupo Estadistico 3"
  }

  dimension: nom_grupo_estadistico4 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico4 ;;
    description: "Nom Grupo Estadistico 4"
  }

  dimension: nom_subdireccion {
    type: string
    sql: ${TABLE}.nom_subdireccion ;;
    description: "Nom Subdireccion"
  }

  dimension: nom_gerencia {
    type: string
    sql: ${TABLE}.nom_gerencia ;;
    description: "Nom Gerencia"
  }

  dimension: nom_zona {
    type: string
    sql: ${TABLE}.nom_zona ;;
    description: "Nom Zona"
  }

  dimension: nom_cliente {
    type: string
    sql: ${TABLE}.nom_cliente ;;
    description: "Nombre cliente"
    group_item_label: "Filtros"
  }

  dimension: zona {
    type: string
    sql: ${TABLE}.zona ;;
    description: "Zona"
    group_item_label: "Filtros"
  }

  dimension: nom_estado {
    type: string
    sql: ${TABLE}.nom_estado ;;
    description: "Nombre estado"
    group_item_label: "Filtros"
  }

  dimension: nom_canal {
    type: string
    sql: ${TABLE}.nom_canal ;;
    description: "Nombre canal"
    group_item_label: "Filtros"
  }

  # ============================================
  # MEASURES (Valores numéricos calculables)
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail*]
  }

  measure: precio_usd {
    type: max
    sql: ${TABLE}.precio_usd ;;
    value_format_name: usd
    description: "Precio en USD"
  }

  measure: precio_importacion_mxn {
    type: max
    sql: ${TABLE}.precio_importacion_mxn ;;
    value_format_name: usd
    description: "Precio de importación convertido a MXN (precio_usd * Tipo_Cambio)"
  }

  measure: precio_caida_mxn {
    type: max
    sql: ${TABLE}.precio_caida_mxn ;;
    value_format_name: usd
    description: "Precio caída de pedidos en MXN (D9: imp_precio_entrega_mn / toneladas_caida_de_pedidos)"
  }

  # Promedio ponderado del precio de caída por toneladas_caida_de_pedidos (D9)
  measure: precio_caida_ponderado {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.precio_caida_mxn * ${TABLE}.toneladas_caida_de_pedidos),
      NULLIF(SUM(${TABLE}.toneladas_caida_de_pedidos), 0)
    ) ;;
    value_format_name: usd
    description: "Precio caída promedio ponderado por toneladas caída (D9)"
  }

  measure: precio_senial {
    type: max
    sql: ${TABLE}.precio_senial_calculado ;;
    value_format_name: usd
    description: "Precio señal calculado por grupo estadístico (KPI #1 / D5)"
  }

  # Precio señal ponderado por toneladas de caída (KPI #1)
  measure: precio_senial_ponderado {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.importe_senial_ponderado),
      NULLIF(SUM(${TABLE}.toneladas_caida_de_pedidos), 0)
    ) ;;
    value_format_name: usd
    description: "Precio señal ponderado = SUM(importe_señal) / SUM(toneladas_caida) (KPI #1)"
  }

  measure: variacion_importacion_pct {
    type: max
    sql: ${TABLE}.variacion_importacion_pct ;;
    value_format_name: decimal_2
    description: "Variación porcentual semanal del precio de importación en MXN (%)"
  }

  measure: variacion_caida_pct {
    type: max
    sql: ${TABLE}.variacion_caida_pct ;;
    value_format_name: decimal_2
    description: "Variación porcentual semanal del precio de caída (%) (D9)"
  }

  measure: senal_porcentual {
    type: max
    sql: ${TABLE}.senal_porcentual ;;
    value_format_name: decimal_2
    description: "Desvío porcentual del precio de caída vs precio señal objetivo (%) (D5)"
  }

  measure: indice_precio {
    type: max
    sql: ${TABLE}.indice_precio ;;
    value_format_name: decimal_4
    description: "Índice de precio = precio_caída / precio_pulso. Métrica derivada construida en el LookML como apoyo visual del cuadrante; no aparece en el catálogo oficial (kpis_sin_documentar.csv). Valor >1 indica precio caída por encima del pulso de mercado."
  }

  measure: tipo_cambio {
    type: max
    sql: ${TABLE}.Tipo_Cambio ;;
    value_format_name: decimal_2
    description: "Tipo de cambio para conversión USD->MXN. Fuente: mart comercial (diario). D11 documenta una segunda fuente semanal en Google Sheets para precios internacionales; aquí se usa la diaria del mart por disponibilidad en BigQuery."
  }

  # ============================================
  # Precios de llegada y premiums de importación (KPIs #4-7 / D4)
  # ============================================

  measure: precio_importacion_llegada1 {
    type: max
    sql: ${TABLE}.precio_importacion_llegada1 ;;
    value_format_name: usd
    description: "Precio CIF + aranceles de llegada, referencia 1 (KPI #4)"
  }

  measure: precio_importacion_llegada2 {
    type: max
    sql: ${TABLE}.precio_importacion_llegada2 ;;
    value_format_name: usd
    description: "Precio CIF + aranceles de llegada, referencia 2 (KPI #5)"
  }

  measure: premium_importacion1 {
    type: max
    sql: ${TABLE}.premium_importacion1 ;;
    value_format_name: percent_2
    description: "Premium de importación ref.1 = (Precio Facturación / Precio CIF Llegada) - 1 (KPI #6 / D4)"
  }

  measure: premium_importacion2 {
    type: max
    sql: ${TABLE}.premium_importacion2 ;;
    value_format_name: percent_2
    description: "Premium de importación ref.2 (KPI #7 / D4)"
  }

  measure: precio_pulso {
    type: max
    sql: ${TABLE}.precio_pulso ;;
    value_format_name: usd
    description: "Precio pulso en MXN (KPI #10)"
  }

  measure: precio_pulso_min {
    type: min
    sql: ${TABLE}.precio_pulso ;;
    value_format_name: usd
    description: "Precio pulso mínimo en MXN (KPI #11)"
  }

  measure: precio_pulso_max {
    type: max
    sql: ${TABLE}.precio_pulso ;;
    value_format_name: usd
    description: "Precio pulso máximo en MXN (KPI #12)"
  }

  measure: toneladas_caida_total {
    type: sum
    sql: ${TABLE}.toneladas_caida_de_pedidos ;;
    value_format_name: decimal_2
    description: "Toneladas caída de pedidos (base de ponderación)"
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
      precio_importacion_mxn,
      precio_caida_mxn,
      precio_caida_ponderado,
      precio_senial,
      precio_senial_ponderado,
      variacion_importacion_pct,
      variacion_caida_pct,
      senal_porcentual,
      indice_precio,
      tipo_cambio,
      precio_pulso,
      precio_pulso_min,
      precio_pulso_max,
      toneladas_caida_total,
      precio_importacion_llegada1,
      precio_importacion_llegada2,
      premium_importacion1,
      premium_importacion2
    ]
  }
}

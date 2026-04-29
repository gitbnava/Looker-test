view: cuadrante_izquierdo_superior {
  derived_table: {
    sql:
      -- Optimizado: filtro 90 días, una sola pasada UNNEST en lugar de 9 UNION ALL
      -- Alineado a definiciones D5, D9, D11 y KPIs #1, #2-23
      --
      -- VENTANA TEMPORAL DINÁMICA (Liquid):
      --   - Sin filtro fecha_contable del dashboard: últimas 6 semanas cronológicas (90d partition prune).
      --   - Con filtro fecha_contable: se respeta el rango del usuario; se omite el LIMIT 6
      --     y se inyecta un condition de Liquid sobre la columna `fecha` particionada
      --     para mantener partition pruning.
      {% assign tiene_filtro = _filters['cuadrante_izquierdo_superior.fecha_contable']._parameter_value %}
      WITH
      -- Bloque transaccional del mart (control IN (1, 6)):
      --   control=1: transacciones facturación/entrega principales
      --   control=6: flujos complementarios con imp_entrega capturado
      -- Excluidos: control=101 (sin tons_caida ni imp_entrega), control=103 (finanzas),
      -- control=8 (plantilla maestra sin TC ni imp_entrega reales).
      --
      -- REGLA DE NEGOCIO: sin filtro del usuario, se toman las últimas 6 semanas CRONOLÓGICAS,
      -- independientemente de si tienen datos de índices internacionales. Los índices internacionales
      -- pueden capturarse con lag (2-4 semanas), por lo que algunas semanas recientes tendrán
      -- precios = 0 en lugar de valor. Esto es intencional.
      semanas_disponibles AS (
        SELECT DISTINCT anio_semana AS semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        WHERE fecha IS NOT NULL
          AND anio_semana IS NOT NULL
          AND control IN (1, 6)
          AND {% condition fecha_contable %} fecha {% endcondition %}
          {% if tiene_filtro == nil or tiene_filtro == "" %}
            AND fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
            AND fecha <= CURRENT_DATE()
          {% endif %}
        ORDER BY anio_semana DESC
        {% if tiene_filtro == nil or tiene_filtro == "" %}
          LIMIT 6
        {% endif %}
      ),
      -- Precios de importación agregados por semana (de cualquier fila con esos campos)
      -- Desacoplado de GE para que funcione con cualquier filtro de producto
      -- Fuente Tipo_Cambio: mart comercial (diario).
      -- D11 documenta adicionalmente una fuente semanal en Google Sheets para la sección
      -- de precios internacionales. Aquí se usa el TC del mart por disponibilidad en BigQuery
      -- y por consistencia con las transacciones.
      --
      -- MANEJO DE NULOS (regla de negocio):
      -- - Los índices internacionales pueden estar ausentes en las últimas 2-4 semanas
      --   por lag de captura. En lugar de omitir esas semanas, se usa COALESCE(..., 0)
      --   para que el AVG devuelva 0 cuando no hay dato. Esto permite preservar las 6
      --   semanas cronológicas en el resultado final.
      -- - Tipo_Cambio conserva NULL si no existe, para que la conversión a MXN no use TC=0
      --   (se hace COALESCE en el cálculo de precio_mxn en el CTE precios_unificados).
      ref_por_semana AS (
        SELECT
          anio_semana AS semana,
          AVG(CASE WHEN SAFE_CAST(Tipo_Cambio AS FLOAT64) > 5 THEN SAFE_CAST(Tipo_Cambio AS FLOAT64) END) AS Tipo_Cambio,
          -- Cotizaciones de importación por país en MXN (modelo nuevo del mart, ya pre-convertido).
          -- Reemplaza el bloque legado de índices internacionales (Rebar_FOB_*, Indice_AMM_*, etc.).
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_china_mxn > 0 THEN precio_importacion_cotizacion_china_mxn END), 0) AS cotiz_china_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_malasia_mxn > 0 THEN precio_importacion_cotizacion_malasia_mxn END), 0) AS cotiz_malasia_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_spain_mxn > 0 THEN precio_importacion_cotizacion_spain_mxn END), 0) AS cotiz_spain_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_italia_mxn > 0 THEN precio_importacion_cotizacion_italia_mxn END), 0) AS cotiz_italia_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_japon_mxn > 0 THEN precio_importacion_cotizacion_japon_mxn END), 0) AS cotiz_japon_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_luxemburgo_mxn > 0 THEN precio_importacion_cotizacion_luxemburgo_mxn END), 0) AS cotiz_luxemburgo_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_sudeste_asiatico_mxn > 0 THEN precio_importacion_cotizacion_sudeste_asiatico_mxn END), 0) AS cotiz_sudeste_asiatico_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_turquia_mxn > 0 THEN precio_importacion_cotizacion_turquia_mxn END), 0) AS cotiz_turquia_mxn,
          COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_vietnam_mxn > 0 THEN precio_importacion_cotizacion_vietnam_mxn END), 0) AS cotiz_vietnam_mxn,
          -- Señales de precio por grupo estadístico (KPI #1 / D5)
          COALESCE(AVG(CASE WHEN Senal_Varilla > 0 THEN Senal_Varilla END), 0) AS senal_varilla,
          COALESCE(AVG(CASE WHEN Senal_Alambron > 0 THEN Senal_Alambron END), 0) AS senal_alambron,
          COALESCE(AVG(CASE WHEN Senal_Angulos_AAA > 0 THEN Senal_Angulos_AAA END), 0) AS senal_angulos_aaa,
          -- Precios CIF de llegada y premiums de importación (KPIs #4-7 / D4)
          COALESCE(AVG(CASE WHEN precio_importacion_llegada1 > 0 THEN precio_importacion_llegada1 END), 0) AS precio_importacion_llegada1,
          COALESCE(AVG(CASE WHEN precio_importacion_llegada2 > 0 THEN precio_importacion_llegada2 END), 0) AS precio_importacion_llegada2,
          COALESCE(AVG(premium_importacion1), 0) AS premium_importacion1,
          COALESCE(AVG(premium_importacion2), 0) AS premium_importacion2
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        WHERE anio_semana IN (SELECT semana FROM semanas_disponibles)
          AND control IN (1, 6)  -- bloque transaccional (ver comentario en semanas_disponibles)
          -- Se quita el filtro `SAFE_CAST(Tipo_Cambio) > 0` del WHERE para no eliminar
          -- filas donde los índices internacionales existen pero TC aún no se ha poblado.
          -- El filtro TC se mantiene en el CASE WHEN del AVG para limpiar valores ruido.
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
          r.cotiz_china_mxn,
          r.cotiz_malasia_mxn,
          r.cotiz_spain_mxn,
          r.cotiz_italia_mxn,
          r.cotiz_japon_mxn,
          r.cotiz_luxemburgo_mxn,
          r.cotiz_sudeste_asiatico_mxn,
          r.cotiz_turquia_mxn,
          r.cotiz_vietnam_mxn,
          -- Precios CIF de llegada y premiums (KPIs #4-7 / D4)
          r.precio_importacion_llegada1,
          r.precio_importacion_llegada2,
          r.premium_importacion1,
          r.premium_importacion2
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial` v
        -- LEFT JOIN permite preservar filas transaccionales aunque ref_por_semana no tenga
        -- Tipo_Cambio para la semana. precio_mxn será NULL pero precio_caida_pedidos se preserva.
        LEFT JOIN ref_por_semana r ON v.anio_semana = r.semana
        WHERE v.fecha IS NOT NULL
          AND v.anio_semana IN (SELECT semana FROM semanas_disponibles)
          AND v.control IN (1, 6)  -- bloque transaccional (ver comentario en semanas_disponibles)
          AND {% condition fecha_contable %} v.fecha {% endcondition %}
          {% if tiene_filtro == nil or tiene_filtro == "" %}
            AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
          {% endif %}
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
          ref.pais,
          -- precio_mxn: cotización por país en MXN, ya pre-calculada en el mart
          -- (validado V7: ratio_mxn_usd coincide con tipo_cambio_importacion).
          -- Las semanas/países sin dato aparecen con precio_mxn = 0 por el COALESCE en ref_por_semana.
          ref.precio_mxn
        FROM precios_internacionales p
        CROSS JOIN UNNEST([
          STRUCT('China' AS pais, p.cotiz_china_mxn AS precio_mxn),
          STRUCT('Malasia' AS pais, p.cotiz_malasia_mxn AS precio_mxn),
          STRUCT('Spain' AS pais, p.cotiz_spain_mxn AS precio_mxn),
          STRUCT('Italia' AS pais, p.cotiz_italia_mxn AS precio_mxn),
          STRUCT('Japón' AS pais, p.cotiz_japon_mxn AS precio_mxn),
          STRUCT('Luxemburgo' AS pais, p.cotiz_luxemburgo_mxn AS precio_mxn),
          STRUCT('Sudeste Asiático' AS pais, p.cotiz_sudeste_asiatico_mxn AS precio_mxn),
          STRUCT('Turquía' AS pais, p.cotiz_turquia_mxn AS precio_mxn),
          STRUCT('Vietnam' AS pais, p.cotiz_vietnam_mxn AS precio_mxn)
        ]) AS ref
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
      pais,
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
      LAG(precio_mxn) OVER (PARTITION BY pais ORDER BY semana ASC, fecha_contable ASC) AS precio_importacion_semana_anterior,
      LAG(precio_caida_pedidos) OVER (PARTITION BY pais ORDER BY semana ASC, fecha_contable ASC) AS precio_caida_semana_anterior,
      -- indice_precio: relación precio caída / pulso.
      -- Métrica derivada construida en este LookML como apoyo visual del cuadrante.
      -- No aparece explícitamente en el catálogo oficial (kpis_sin_documentar.csv, D1-D19),
      -- por lo que se mantiene como complementaria. Uso: >1 indica precio caída por encima del pulso.
      SAFE_DIVIDE(precio_caida_pedidos, precio_pulso) AS indice_precio
      FROM precios_unificados
      -- Ya no se filtra precio_mxn > 0 para preservar 6 semanas cronológicas.
      -- Las semanas sin índices internacionales aparecerán con precio_mxn = 0.
      )

      SELECT
      pais,
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
      precio_mxn AS precio_importacion_mxn,
      precio_caida_mxn,
      precio_senial_calculado,
      importe_senial_ponderado,
      toneladas_caida_de_pedidos,
      -- Variación porcentual semanal del precio de importación en MXN (0 si no hay dato previo)
      COALESCE(ROUND(SAFE_DIVIDE((precio_mxn - precio_importacion_semana_anterior), precio_importacion_semana_anterior) * 100, 2), 0) AS variacion_importacion_pct,
      -- Variación porcentual semanal del precio de caída (D9)
      COALESCE(ROUND(SAFE_DIVIDE((precio_caida_mxn - precio_caida_semana_anterior), precio_caida_semana_anterior) * 100, 2), 0) AS variacion_caida_pct,
      -- Señal porcentual: desvío entre precio de caída real vs precio señal objetivo (D5 / KPI #1)
      COALESCE(ROUND(SAFE_DIVIDE((precio_caida_mxn - precio_senial_calculado), precio_senial_calculado) * 100, 2), 0) AS senal_porcentual,
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

  dimension: pais {
    type: string
    sql: ${TABLE}.pais ;;
    description: "País de origen de la cotización de importación (China, Malasia, Spain, Italia, Japón, Luxemburgo, Sudeste Asiático, Turquía, Vietnam)"
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

  measure: precio_importacion_mxn {
    type: max
    sql: ${TABLE}.precio_importacion_mxn ;;
    value_format_name: usd
    description: "Precio cotización de importación por país en MXN (lectura directa del mart, ya pre-convertido)"
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
      pais,
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

view: cuadrante_izquierdo_inferior {
  derived_table: {
    sql:
      -- =====================================================
      -- QUERY CUADRANTE INFERIOR IZQUIERDO
      -- Medidor de Precio + KPIs + Gráfico Combinado Temporal
      --
      -- ARQUITECTURA: subqueries por control (Opción A).
      -- Cada serie de toneladas vive en un control distinto del mart:
      --   - toneladas_caida_de_pedidos → control IN (1, 6) (transaccional)
      --   - toneladas_facturadas       → control = 3 (facturación)
      --   - toneladas_pvo              → control = 4 (PVO/forecast)
      -- Por eso se construye un CTE por bloque y se unen por semana.
      --
      -- VENTANA TEMPORAL DINÁMICA (Liquid):
      --   - Sin filtro fecha_contable: últimas 6 semanas cronológicas (90d partition prune).
      --   - Con filtro fecha_contable: se respeta el rango del usuario; se omite el LIMIT 6.
      -- =====================================================
      {% assign tiene_filtro = _filters['cuadrante_izquierdo_inferior.fecha_contable']._parameter_value %}
      WITH
      -- Semanas a mostrar: 6 cronológicas hacia atrás + todas las semanas futuras con predicción.
      -- Sin filtro del usuario: 6 últimas + horizonte futuro disponible.
      -- Con filtro del usuario: respeta el rango de fecha_contable, sin agregar futuras.
      semanas_disponibles AS (
        SELECT semana FROM (
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
        )
        {% if tiene_filtro == nil or tiene_filtro == "" %}
        UNION DISTINCT
        -- Semanas futuras con predicción disponible (sin LIMIT — se incluyen todas las que el mart tenga).
        SELECT DISTINCT anio_semana AS semana
        FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
        WHERE fecha > CURRENT_DATE()
          AND anio_semana IS NOT NULL
          AND predicciones IS NOT NULL
        {% endif %}
      ),

      -- Bloque 1: TRANSACCIONAL (control IN 1, 6)
      -- Aporta: precio_caida_pedidos (D9), señal de precio, toneladas_caida_de_pedidos.
      -- Mantiene granularidad por fila para preservar filtros en tiles (cliente, canal, zona, GE).
      datos_caida AS (
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
      SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) AS toneladas_caida_de_pedidos,
      SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) AS imp_precio_entrega_mn,
      -- precio_caida_pedidos (D9): imp_precio_entrega_mn / toneladas_caida_de_pedidos.
      -- Bug previo corregido: antes usaba toneladas_pedidas (denominador incorrecto).
      CASE
      WHEN SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) >= 1
      AND SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64) > 0
      THEN SAFE_DIVIDE(
      SAFE_CAST(v.imp_precio_entrega_mn AS FLOAT64),
      SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
      )
      ELSE NULL
      END AS precio_caida_pedidos,
      SAFE_CAST(v.importe_precio_senial AS FLOAT64) AS importe_precio_senial,
      -- precio_senial: importe_precio_senial / toneladas_caida_de_pedidos (validado con funcional).
      -- Bug previo corregido: antes leía v.precio_senial (campo inexistente).
      CASE
      WHEN SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64) >= 1
      AND SAFE_CAST(v.importe_precio_senial AS FLOAT64) > 0
      THEN SAFE_DIVIDE(
      SAFE_CAST(v.importe_precio_senial AS FLOAT64),
      SAFE_CAST(v.toneladas_caida_de_pedidos AS FLOAT64)
      )
      ELSE NULL
      END AS precio_senial
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial` v
      WHERE v.anio_semana IN (SELECT semana FROM semanas_disponibles)
      AND v.fecha IS NOT NULL
      AND v.control IN (1, 6)
      AND {% condition fecha_contable %} v.fecha {% endcondition %}
      {% if tiene_filtro == nil or tiene_filtro == "" %}
      AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
      {% endif %}
      ),

      -- Bloque 2: FACTURACIÓN (control = 3)
      -- Aporta: toneladas_facturadas. Agregadas por semana (no se cruzan filtros porque control 3
      -- no comparte granularidad cliente/canal con el bloque transaccional).
      facturadas_por_semana AS (
      SELECT
      v.anio_semana AS semana,
      SUM(SAFE_CAST(v.toneladas_facturadas AS FLOAT64)) AS toneladas_facturadas_total
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial` v
      WHERE v.anio_semana IN (SELECT semana FROM semanas_disponibles)
      AND v.fecha IS NOT NULL
      AND v.control = 3
      AND {% condition fecha_contable %} v.fecha {% endcondition %}
      {% if tiene_filtro == nil or tiene_filtro == "" %}
      AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
      {% endif %}
      GROUP BY v.anio_semana
      ),

      -- Bloque 3: PVO / FORECAST (control = 4)
      -- Aporta: toneladas_pvo + imp_facturado_exworks_mn (para precio OPVO).
      pvo_por_semana AS (
      SELECT
      v.anio_semana AS semana,
      SUM(SAFE_CAST(v.toneladas_pvo AS FLOAT64)) AS toneladas_pvo_total,
      SUM(SAFE_CAST(v.imp_facturado_exworks_mn AS FLOAT64)) AS imp_facturado_exworks_total
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial` v
      WHERE v.anio_semana IN (SELECT semana FROM semanas_disponibles)
      AND v.fecha IS NOT NULL
      AND v.control = 4
      AND {% condition fecha_contable %} v.fecha {% endcondition %}
      {% if tiene_filtro == nil or tiene_filtro == "" %}
      AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
      {% endif %}
      GROUP BY v.anio_semana
      ),

      -- Bloque 4: REFERENCIAS DE PRECIO (TC, Platts, importación país-MXN)
      -- Desacoplado por semana, sin filtro de control para no perder filas con índices.
      -- Migrado al modelo nuevo: 9 cotizaciones país-MXN (consistente con cuadrante superior).
      ref_por_semana AS (
      SELECT
      anio_semana AS semana,
      AVG(CASE WHEN SAFE_CAST(Tipo_Cambio AS FLOAT64) > 5 THEN SAFE_CAST(Tipo_Cambio AS FLOAT64) END) AS Tipo_Cambio,
      AVG(CASE WHEN SAFE_CAST(Platts_total AS FLOAT64) > 0 THEN SAFE_CAST(Platts_total AS FLOAT64) END) AS platts_total,
      -- Cotizaciones de importación por país en MXN (modelo nuevo, ya pre-convertido).
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_china_mxn > 0 THEN precio_importacion_cotizacion_china_mxn END), 0) AS cotiz_china_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_malasia_mxn > 0 THEN precio_importacion_cotizacion_malasia_mxn END), 0) AS cotiz_malasia_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_spain_mxn > 0 THEN precio_importacion_cotizacion_spain_mxn END), 0) AS cotiz_spain_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_italia_mxn > 0 THEN precio_importacion_cotizacion_italia_mxn END), 0) AS cotiz_italia_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_japon_mxn > 0 THEN precio_importacion_cotizacion_japon_mxn END), 0) AS cotiz_japon_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_luxemburgo_mxn > 0 THEN precio_importacion_cotizacion_luxemburgo_mxn END), 0) AS cotiz_luxemburgo_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_sudeste_asiatico_mxn > 0 THEN precio_importacion_cotizacion_sudeste_asiatico_mxn END), 0) AS cotiz_sudeste_asiatico_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_turquia_mxn > 0 THEN precio_importacion_cotizacion_turquia_mxn END), 0) AS cotiz_turquia_mxn,
      COALESCE(AVG(CASE WHEN precio_importacion_cotizacion_vietnam_mxn > 0 THEN precio_importacion_cotizacion_vietnam_mxn END), 0) AS cotiz_vietnam_mxn
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
      WHERE anio_semana IN (SELECT semana FROM semanas_disponibles)
      AND control IN (1, 6)
      GROUP BY anio_semana
      ),

      -- Promedio simple por semana de las 9 cotizaciones país-MXN (línea Precio Importación del combo).
      -- Solo entran países con dato (> 0); las semanas sin ningún país regresan NULL.
      precio_importacion_por_semana AS (
      SELECT
      semana,
      (
      CASE WHEN cotiz_china_mxn > 0 THEN cotiz_china_mxn END +
      CASE WHEN cotiz_malasia_mxn > 0 THEN cotiz_malasia_mxn END +
      CASE WHEN cotiz_spain_mxn > 0 THEN cotiz_spain_mxn END +
      CASE WHEN cotiz_italia_mxn > 0 THEN cotiz_italia_mxn END +
      CASE WHEN cotiz_japon_mxn > 0 THEN cotiz_japon_mxn END +
      CASE WHEN cotiz_luxemburgo_mxn > 0 THEN cotiz_luxemburgo_mxn END +
      CASE WHEN cotiz_sudeste_asiatico_mxn > 0 THEN cotiz_sudeste_asiatico_mxn END +
      CASE WHEN cotiz_turquia_mxn > 0 THEN cotiz_turquia_mxn END +
      CASE WHEN cotiz_vietnam_mxn > 0 THEN cotiz_vietnam_mxn END
      ) /
      NULLIF(
      (CASE WHEN cotiz_china_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_malasia_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_spain_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_italia_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_japon_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_luxemburgo_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_sudeste_asiatico_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_turquia_mxn > 0 THEN 1 ELSE 0 END) +
      (CASE WHEN cotiz_vietnam_mxn > 0 THEN 1 ELSE 0 END),
      0
      ) AS precio_importacion_promedio
      FROM ref_por_semana
      ),

      -- Bloque 5: PREDICCIÓN (modelo funcional, semanal por GE)
      -- Desacoplada de control (V11 confirmó que ALAMBRON/PERFILES viven en control=4 y VARILLA en 1/3).
      -- Solo aplica a VARILLA, ALAMBRON, PERFILES (otros GE no tienen modelo de predicción).
      -- V13 confirmó STDDEV=0 por GE×semana, por lo que MAX captura el valor único correctamente.
      prediccion_por_semana AS (
      SELECT
      anio_semana AS semana,
      nom_grupo_estadistico1,
      MAX(predicciones) AS prediccion,
      MAX(intervalo_bajo) AS intervalo_bajo,
      MAX(intervalo_alto) AS intervalo_alto
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial`
      WHERE anio_semana IN (SELECT semana FROM semanas_disponibles)
      AND predicciones IS NOT NULL
      AND nom_grupo_estadistico1 IN ('VARILLA', 'ALAMBRON', 'PERFILES')
      GROUP BY anio_semana, nom_grupo_estadistico1
      ),

      -- Agregación final por semana × dimensiones de filtro (granularidad cliente/canal/GE).
      -- LEFT JOIN preserva semanas aunque facturadas/pvo/ref/prediccion estén vacíos (regla 6 semanas cronológicas).
      datos_agregados AS (
      SELECT
      c.semana,
      MIN(c.mes) AS mes,
      MIN(c.anio) AS anio,
      MIN(c.trimestre) AS trimestre,
      MIN(c.nombre_periodo_mostrar) AS nombre_periodo_mostrar,
      MIN(c.nom_grupo_estadistico1) AS nom_grupo_estadistico1,
      MIN(c.nom_grupo_estadistico2) AS nom_grupo_estadistico2,
      MIN(c.nom_grupo_estadistico3) AS nom_grupo_estadistico3,
      MIN(c.nom_grupo_estadistico4) AS nom_grupo_estadistico4,
      MIN(c.nom_subdireccion) AS nom_subdireccion,
      MIN(c.nom_gerencia) AS nom_gerencia,
      MIN(c.nom_zona) AS nom_zona,
      MIN(c.nom_cliente) AS nom_cliente,
      MIN(c.zona) AS zona,
      MIN(c.nom_estado) AS nom_estado,
      MIN(c.nom_canal) AS nom_canal,
      MIN(c.fecha_contable) AS fecha_contable_min,
      MAX(c.fecha_contable) AS fecha_contable_max,
      -- Precios ponderados por toneladas_caida_de_pedidos (D9 / KPI #1).
      -- Se reconstruye desde los importes y toneladas crudos para evitar el sesgo del AVG simple.
      SAFE_DIVIDE(
      SUM(CASE WHEN c.toneladas_caida_de_pedidos >= 1 AND c.imp_precio_entrega_mn > 0 THEN c.imp_precio_entrega_mn END),
      NULLIF(SUM(CASE WHEN c.toneladas_caida_de_pedidos >= 1 AND c.imp_precio_entrega_mn > 0 THEN c.toneladas_caida_de_pedidos END), 0)
      ) AS precio_caida_promedio,
      MAX(rps.platts_total) AS platts_promedio,
      SAFE_DIVIDE(
      SUM(CASE WHEN c.toneladas_caida_de_pedidos >= 1 AND c.importe_precio_senial > 0 THEN c.importe_precio_senial END),
      NULLIF(SUM(CASE WHEN c.toneladas_caida_de_pedidos >= 1 AND c.importe_precio_senial > 0 THEN c.toneladas_caida_de_pedidos END), 0)
      ) AS senal_precio_promedio,
      MAX(pi.precio_importacion_promedio) AS precio_importacion_promedio,
      -- Sumas para volumen
      MAX(pvo.toneladas_pvo_total) AS toneladas_pvo_total,
      MAX(fact.toneladas_facturadas_total) AS toneladas_facturadas_total,
      SUM(c.toneladas_caida_de_pedidos) AS toneladas_caida_de_pedidos_total,
      -- Precio OPVO: imp_facturado_exworks (control=4) / toneladas_pvo (control=4)
      SAFE_DIVIDE(MAX(pvo.imp_facturado_exworks_total), MAX(pvo.toneladas_pvo_total)) AS precio_opvo_calculado,
      -- Predicción de precio (modelo funcional, semanal por GE)
      MAX(pred.prediccion) AS prediccion,
      MAX(pred.intervalo_bajo) AS intervalo_bajo,
      MAX(pred.intervalo_alto) AS intervalo_alto
      FROM datos_caida c
      LEFT JOIN ref_por_semana rps ON c.semana = rps.semana
      LEFT JOIN precio_importacion_por_semana pi ON c.semana = pi.semana
      LEFT JOIN facturadas_por_semana fact ON c.semana = fact.semana
      LEFT JOIN pvo_por_semana pvo ON c.semana = pvo.semana
      LEFT JOIN prediccion_por_semana pred
      ON c.semana = pred.semana
      AND c.nom_grupo_estadistico1 = pred.nom_grupo_estadistico1
      GROUP BY c.semana, c.nom_grupo_estadistico1, c.nom_grupo_estadistico2, c.nom_grupo_estadistico3, c.nom_grupo_estadistico4, c.nom_subdireccion, c.nom_gerencia, c.nom_zona, c.nom_cliente, c.zona, c.nom_estado, c.nom_canal
      ),

      -- Agregado puro por semana (sin dimensiones de filtro) para estadísticas globales.
      -- Esto evita el sesgo de calcular STDDEV sobre granularidad cliente×canal×zona×GE.
      precio_caida_por_semana AS (
      SELECT
      c.semana,
      SAFE_DIVIDE(
      SUM(CASE WHEN c.toneladas_caida_de_pedidos >= 1 AND c.imp_precio_entrega_mn > 0 THEN c.imp_precio_entrega_mn END),
      NULLIF(SUM(CASE WHEN c.toneladas_caida_de_pedidos >= 1 AND c.imp_precio_entrega_mn > 0 THEN c.toneladas_caida_de_pedidos END), 0)
      ) AS precio_caida_semanal_ponderado
      FROM datos_caida c
      GROUP BY c.semana
      ),

      -- Estadísticas globales calculadas sobre precios ponderados por semana (1 valor por semana).
      estadisticas_globales AS (
      SELECT
      AVG(precio_caida_semanal_ponderado) AS precio_caida_promedio_global,
      STDDEV(precio_caida_semanal_ponderado) AS precio_caida_stddev_global,
      MIN(precio_caida_semanal_ponderado) AS precio_minimo_historico,
      MAX(precio_caida_semanal_ponderado) AS precio_maximo_historico
      FROM precio_caida_por_semana
      WHERE precio_caida_semanal_ponderado IS NOT NULL
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
      da.prediccion,
      da.intervalo_bajo,
      da.intervalo_alto,
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
      -- Valores para KPIs y medidor (regla negocio: 0 en lugar de NULL para preservar 6 semanas)
      COALESCE(ROUND(precio_caida_promedio, 2), 0) AS precio_caida_promedio,
      COALESCE(ROUND(limite_superior, 2), 0) AS limite_superior,
      COALESCE(ROUND(limite_inferior, 2), 0) AS limite_inferior,
      COALESCE(ROUND(precio_semana_anterior, 2), 0) AS precio_semana_anterior,
      COALESCE(ROUND(precio_minimo_historico, 2), 0) AS precio_minimo_historico,
      COALESCE(ROUND(precio_maximo_historico, 2), 0) AS precio_maximo_historico,
      -- Valores para líneas de precio
      COALESCE(ROUND(platts_promedio, 2), 0) AS platts_promedio,
      COALESCE(ROUND(senal_precio_promedio, 2), 0) AS senal_precio_promedio,
      COALESCE(ROUND(precio_importacion_promedio, 2), 0) AS precio_importacion_promedio,
      COALESCE(ROUND(precio_opvo_calculado, 2), 0) AS precio_opvo_calculado,
      -- Predicción de precio MXN/ton + intervalo de confianza (modelo funcional)
      COALESCE(ROUND(prediccion, 2), 0) AS prediccion,
      COALESCE(ROUND(intervalo_bajo, 2), 0) AS intervalo_bajo,
      COALESCE(ROUND(intervalo_alto, 2), 0) AS intervalo_alto,
      -- Valores para barras de volumen
      COALESCE(ROUND(toneladas_pvo_total, 2), 0) AS toneladas_pvo_total,
      COALESCE(ROUND(toneladas_facturadas_total, 2), 0) AS toneladas_facturadas_total,
      COALESCE(ROUND(toneladas_caida_de_pedidos_total, 2), 0) AS toneladas_caida_de_pedidos_total,
      -- Variación porcentual
      COALESCE(variacion_porcentual_toneladas, 0) AS variacion_porcentual_toneladas,
      -- Formato de semana para etiquetas
      CONCAT('S', SUBSTR(CAST(semana AS STRING), -2)) AS semana_label,
      -- Flag para filtrar KPI tiles a la semana más reciente disponible
      CASE WHEN semana = MAX(semana) OVER () THEN TRUE ELSE FALSE END AS is_ultima_semana
      FROM datos_con_variaciones
      ORDER BY semana ASC ;;
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

  dimension: is_ultima_semana {
    type: yesno
    sql: ${TABLE}.is_ultima_semana ;;
    description: "TRUE si es la semana más reciente disponible. Usar como filtro en tiles KPI para evitar acumulación de semanas."
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

  # Dimensión oculta usada por el filtro global del dashboard (listener).
  # El {% condition fecha_contable %} en el derived_table se inyecta sobre la columna
  # cruda `fecha` de la tabla base para preservar partition pruning.
  dimension: fecha_contable {
    type: date
    datatype: date
    sql: ${TABLE}.fecha_contable_min ;;
    hidden: yes
    description: "Dimensión oculta para filtro de rango de fechas desde el dashboard"
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

  # KPIs y Medidor
  measure: precio_caida_promedio {
    type: max
    sql: ${TABLE}.precio_caida_promedio ;;
    value_format_name: usd
    description: "Precio caída promedio (para medidor y KPIs)"
  }

  measure: limite_superior {
    type: max
    sql: ${TABLE}.limite_superior ;;
    value_format_name: usd
    description: "Límite superior (Promedio + STDDEV)"
  }

  measure: limite_inferior {
    type: max
    sql: ${TABLE}.limite_inferior ;;
    value_format_name: usd
    description: "Límite inferior (Promedio - STDDEV)"
  }

  measure: precio_semana_anterior {
    type: max
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
    type: max
    sql: ${TABLE}.platts_promedio ;;
    value_format_name: usd
    description: "Platts promedio por semana"
  }

  measure: senal_precio_promedio {
    type: max
    sql: ${TABLE}.senal_precio_promedio ;;
    value_format_name: usd
    description: "Señal de precio promedio por semana"
  }

  measure: precio_importacion_promedio {
    type: max
    sql: ${TABLE}.precio_importacion_promedio ;;
    value_format_name: usd
    description: "Precio importación promedio por semana"
  }

  measure: precio_opvo_calculado {
    type: max
    sql: ${TABLE}.precio_opvo_calculado ;;
    value_format_name: usd
    description: "Precio OPVO calculado (si se necesita como precio)"
  }

  # Predicción del modelo funcional (semanal por GE: VARILLA, ALAMBRON, PERFILES)
  measure: prediccion {
    type: max
    sql: ${TABLE}.prediccion ;;
    value_format_name: usd
    description: "Predicción de precio MXN/ton (modelo funcional, semanal por GE). Incluye semanas futuras."
  }

  measure: intervalo_bajo {
    type: max
    sql: ${TABLE}.intervalo_bajo ;;
    value_format_name: usd
    description: "Banda inferior del intervalo de confianza de la predicción"
  }

  measure: intervalo_alto {
    type: max
    sql: ${TABLE}.intervalo_alto ;;
    value_format_name: usd
    description: "Banda superior del intervalo de confianza de la predicción"
  }

  # Volumen (Barras)
  measure: toneladas_pvo_total {
    type: max
    sql: ${TABLE}.toneladas_pvo_total ;;
    value_format_name: decimal_2
    description: "Toneladas PVO totales por semana (control=4). type:max porque ya viene pre-agregado por semana desde el CTE pvo_por_semana — usar SUM duplicaría por cada combinación de filtros."
  }

  measure: toneladas_facturadas_total {
    type: max
    sql: ${TABLE}.toneladas_facturadas_total ;;
    value_format_name: decimal_2
    description: "Toneladas facturadas totales por semana (control=3). type:max porque ya viene pre-agregado por semana desde el CTE facturadas_por_semana."
  }

  measure: toneladas_caida_de_pedidos_total {
    type: sum
    sql: ${TABLE}.toneladas_caida_de_pedidos_total ;;
    value_format_name: decimal_2
    description: "Toneladas caída de pedidos totales por semana"
  }

  measure: variacion_porcentual_toneladas {
    type: max
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
      prediccion,
      intervalo_bajo,
      intervalo_alto,
      toneladas_pvo_total,
      toneladas_facturadas_total,
      toneladas_caida_de_pedidos_total,
      variacion_porcentual_toneladas
    ]
  }
}

# =====================================================
# Tablero por Dirección y GII (Grupo de inventario) — Facturación LATAM v2
# Versión jerárquica 6 niveles: Dirección → Subdirección → Gerencia → GE1 → GE2 → GE3
# (GE4 descartado por petición funcional)
# Bloque MERCADO retirado del set de detalle (medidas siguen definidas por si se
# usan en otros tiles, pero no aparecen en el tile principal).
# Fuente: ven_mart_comercial
# =====================================================

view: tablero_direccion_gii_v2 {
  derived_table: {
    sql:
      SELECT
        v.nom_direccion,
        v.nom_grupo_estadistico1 AS gii,
        v.nom_grupo_estadistico1,
        v.nom_grupo_estadistico2,
        v.nom_grupo_estadistico3,
        v.nom_subdireccion,
        v.nom_gerencia,
        v.nom_zona,
        v.nom_cliente_unico AS nom_cliente,
        v.nom_zona AS zona,
        v.nom_estado_consignado AS nom_estado,
        v.nom_canal,
        v.control,
        v.anio,
        v.anio_mes AS mes,
        v.anio_semana AS semana,
        v.nombre_periodo_mostrar,
        v.fecha AS fecha_contable,
        v.toneladas_pedidas,
        v.toneladas_deuda_total,
        v.toneladas_deuda_libre,
        v.toneladas_deuda_auto_fleteo AS deuda_autofleteo,
        v.toneladas_deuda_mes_resto,
        v.toneladas_deuda_mes_siguiente,
        v.toneladas_facturadas,
        v.imp_precio_entrega_mn AS imp_facturacion_mn,
        v.toneladas_pvo,
        v.toneladas_business_plan
      FROM `datahub-deacero.mart_comercial.ven_mart_comercial` AS v
      WHERE v.nom_direccion IS NOT NULL
        AND v.nom_grupo_estadistico1 IS NOT NULL
        AND v.nom_grupo_estadistico1 != ''
        AND v.anio IS NOT NULL
        AND v.fecha IS NOT NULL
        AND v.fecha >= DATE_SUB(CURRENT_DATE(), INTERVAL 48 MONTH)
        AND v.fecha <= DATE_ADD(CURRENT_DATE(), INTERVAL 12 MONTH)
        AND (v.anio_mes IS NOT NULL OR v.anio_semana IS NOT NULL)
    ;;
  }

  # ============================================
  # DIMENSIONES DE FILA (cascada jerárquica)
  # ============================================

  dimension: nom_direccion {
    type: string
    sql: ${TABLE}.nom_direccion ;;
    description: "Nivel 1 de la jerarquía. Dirección (ej. ACEROS MEXICO, FILIALES, EXPORTACION LATAM)."
  }

  dimension: nom_subdireccion {
    type: string
    sql: ${TABLE}.nom_subdireccion ;;
    description: "Nivel 2. Subdirección."
  }

  dimension: nom_gerencia {
    type: string
    sql: ${TABLE}.nom_gerencia ;;
    description: "Nivel 3. Gerencia."
  }

  dimension: gii {
    type: string
    sql: ${TABLE}.gii ;;
    description: "Nivel 4. Grupo de inventario / GE1 (Varilla, Alambrón, Mallas, Perfiles, etc.)."
  }

  dimension: nom_grupo_estadistico1 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico1 ;;
    description: "Gpo. Estadístico 1 (alias de gii)."
  }

  dimension: nom_grupo_estadistico2 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico2 ;;
    description: "Nivel 5. Gpo. Estadístico 2."
  }

  dimension: nom_grupo_estadistico3 {
    type: string
    sql: ${TABLE}.nom_grupo_estadistico3 ;;
    description: "Nivel 6 (último). Gpo. Estadístico 3."
  }

  # ---- Dimensiones auxiliares (no entran en la cascada principal) ----

  dimension: nom_zona {
    type: string
    sql: ${TABLE}.nom_zona ;;
    description: "Zona"
  }

  dimension: zona {
    type: string
    sql: ${TABLE}.zona ;;
    description: "Zona (alias)"
  }

  dimension: nom_estado {
    type: string
    sql: ${TABLE}.nom_estado ;;
    description: "Estado"
  }

  dimension: nom_canal {
    type: string
    sql: ${TABLE}.nom_canal ;;
    description: "Canal Cliente"
  }

  dimension: nom_cliente {
    type: string
    sql: ${TABLE}.nom_cliente ;;
    description: "Cliente"
  }

  # ============================================
  # DIMENSIONES DE PERIODO
  # ============================================

  dimension: anio {
    type: number
    sql: ${TABLE}.anio ;;
    description: "Año"
  }

  dimension: mes {
    type: number
    sql: ${TABLE}.mes ;;
    description: "Mes (anio_mes)"
  }

  dimension: semana {
    type: string
    sql: ${TABLE}.semana ;;
    description: "Semana (anio_semana)"
  }

  dimension: nombre_periodo_mostrar {
    type: string
    sql: ${TABLE}.nombre_periodo_mostrar ;;
    description: "Período para mostrar (ej. Feb-2026). Filtro principal del dashboard."
  }

  dimension_group: fecha_contable {
    type: time
    sql: ${TABLE}.fecha_contable ;;
    description: "Fecha contable."
    timeframes: [date]
  }

  # ============================================
  # DIMENSIONES HIDDEN (periodo actual y ajuste por avance)
  # ============================================

  dimension: es_periodo_actual {
    type: yesno
    sql: FORMAT_DATE('%Y%m', ${TABLE}.fecha_contable) = FORMAT_DATE('%Y%m', CURRENT_DATE()) ;;
    hidden: yes
    description: "Flag: la fila pertenece al periodo (mes) actual. Uso interno para filtro default del dashboard."
  }

  dimension: avance_periodo_actual {
    type: number
    sql:
      CASE
        WHEN FORMAT_DATE('%Y%m', ${TABLE}.fecha_contable) = FORMAT_DATE('%Y%m', CURRENT_DATE())
        THEN SAFE_DIVIDE(
          EXTRACT(DAY FROM CURRENT_DATE()),
          EXTRACT(DAY FROM LAST_DAY(CURRENT_DATE(), MONTH))
        )
        ELSE 1.0
      END ;;
    hidden: yes
    description: "Proporción de días transcurridos del periodo actual. 1.0 para meses cerrados. Usado por pct_pvo y pct_bp."
  }

  # ============================================
  # MEDIDAS AUXILIARES (hidden)
  # ============================================

  measure: total_imp_precio_entrega_mn_control_6 {
    type: sum
    sql: CASE WHEN ${TABLE}.control = 6 THEN ${TABLE}.imp_facturacion_mn END ;;
    hidden: yes
    description: "Importe precio entrega MN filtrado a control=6 (deuda). Usado por precio_deuda_total."
  }

  measure: total_toneladas_deuda_total {
    type: sum
    sql: ${TABLE}.toneladas_deuda_total ;;
    hidden: yes
    description: "Suma total de toneladas de deuda. Denominador de precio_deuda_total."
  }

  # ============================================
  # MEDIDAS PRINCIPALES
  # ============================================

  measure: count {
    type: count
    drill_fields: [detail_jerarquico_6niveles*]
  }

  # ---- Bloque PEDIDOS ----

  measure: pedidos_ton {
    type: sum
    sql: ${TABLE}.toneladas_pedidas ;;
    value_format: "#,##0"
    label: "Pedidos Ton"
    description: "Pedidos Ton (suma de toneladas pedidas)."
    group_label: "Pedidos"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  # ---- Bloque DEUDA ----

  measure: precio_deuda_total {
    type: number
    sql: SAFE_DIVIDE(${total_imp_precio_entrega_mn_control_6}, NULLIF(${total_toneladas_deuda_total}, 0)) ;;
    label: "Deuda PM ($/ton)"
    value_format: "$#,##0.00"
    description: "Deuda PM = SUM(imp_precio_entrega_mn [control=6]) / SUM(toneladas_deuda_total). Equivalente a 'Precio Deuda Total MN' de Tableau."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: deuda_total {
    type: sum
    sql: ${TABLE}.toneladas_deuda_total ;;
    value_format: "#,##0"
    label: "Deuda Total"
    description: "Deuda Total (toneladas_deuda_total)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: deuda_libre {
    type: sum
    sql: ${TABLE}.toneladas_deuda_libre ;;
    value_format: "#,##0"
    label: "Deuda Libre"
    description: "Deuda Libre (toneladas_deuda_libre)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: deuda_autofleteo {
    type: sum
    sql: ${TABLE}.deuda_autofleteo ;;
    value_format: "#,##0"
    label: "Deuda Autofleteo"
    description: "Deuda Autofleteo (toneladas_deuda_auto_fleteo)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: deuda_mes_resto {
    type: sum
    sql: ${TABLE}.toneladas_deuda_mes_resto ;;
    value_format: "#,##0"
    label: "Deuda Mes Resto"
    description: "Deuda Mes Resto (toneladas_deuda_mes_resto)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: deuda_mes_siguiente {
    type: sum
    sql: ${TABLE}.toneladas_deuda_mes_siguiente ;;
    value_format: "#,##0"
    label: "Deuda Mes Siguiente"
    description: "Deuda Mes Siguiente (toneladas_deuda_mes_siguiente)."
    group_label: "Deuda"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  # ---- Bloque FACTURACIÓN ----

  measure: fact_ayer {
    type: sum
    sql: CASE
      WHEN ${TABLE}.fecha_contable = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format: "#,##0"
    label: "Fact Ayer"
    description: "Fact Ayer (toneladas facturadas el día anterior)."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: fact_acum {
    type: sum
    sql: ${TABLE}.toneladas_facturadas ;;
    value_format: "#,##0"
    label: "Fact Acum"
    description: "Fact Acum (suma de toneladas facturadas en el periodo)."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: fact_acum_importe {
    type: sum
    sql: ${TABLE}.imp_facturacion_mn ;;
    value_format: "$#,##0.00"
    label: "Fact Acum Importe"
    description: "Fact Acum importe (suma imp_precio_entrega_mn)."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: precio_destino_mn {
    type: number
    sql: SAFE_DIVIDE(${fact_acum_importe}, NULLIF(${fact_acum}, 0)) ;;
    value_format: "$#,##0.00"
    label: "Precio Destino MN (Fact PM)"
    description: "Precio Destino MN por tonelada. Incluye flete (Datalake ID 69). NO es Precio ExWorks."
    group_label: "Facturación"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  # ---- Bloque VENTAS (PVO / BP) ----

  measure: pvo {
    type: sum
    sql: ${TABLE}.toneladas_pvo ;;
    value_format: "#,##0"
    label: "PVO"
    description: "PVO (toneladas plan de ventas operativo)."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: pct_pvo {
    type: number
    sql: 100.0 * ${fact_acum} / NULLIF(${pvo} * AVG(${avance_periodo_actual}), 0) ;;
    value_format: "#,##0.00\"%\""
    label: "% PVO"
    description: "% PVO ajustado por avance del periodo. Para meses cerrados el ajuste es 1.0."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: bp {
    type: sum
    sql: ${TABLE}.toneladas_business_plan ;;
    value_format: "#,##0"
    label: "BP"
    description: "BP (toneladas Budget Plan)."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: pct_bp {
    type: number
    sql: 100.0 * ${fact_acum} / NULLIF(${bp} * AVG(${avance_periodo_actual}), 0) ;;
    value_format: "#,##0.00\"%\""
    label: "% BP"
    description: "% BP ajustado por avance del periodo. Para meses cerrados el ajuste es 1.0."
    group_label: "Ventas"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  # ---- Bloque HISTÓRICO ----

  measure: fact_acum_2025 {
    type: sum
    sql: CASE
      WHEN SAFE_CAST(${anio} AS INT64) = 2025
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format: "#,##0"
    label: "2025"
    description: "Toneladas facturadas en 2025."
    group_label: "Histórico"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  measure: fact_acum_2026 {
    type: sum
    sql: CASE
      WHEN SAFE_CAST(${anio} AS INT64) = 2026
        AND ${TABLE}.toneladas_facturadas IS NOT NULL
        AND ${TABLE}.toneladas_facturadas <> 0
      THEN ${TABLE}.toneladas_facturadas
      ELSE 0
    END ;;
    value_format: "#,##0"
    label: "2026"
    description: "Toneladas facturadas en 2026."
    group_label: "Histórico"
    drill_fields: [detail_jerarquico_6niveles*]
  }

  # ============================================
  # SETS (filtros del dashboard y drill)
  # ============================================

  set: filtros {
    fields: [
      nom_grupo_estadistico1,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3,
      nombre_periodo_mostrar,
      mes,
      anio,
      semana,
      fecha_contable_date,
      nom_gerencia,
      nom_canal,
      nom_subdireccion,
      nom_zona,
      nom_estado
    ]
  }

  # ---- Jerarquía principal: 6 niveles ----
  # Orden: Dirección → Subdirección → Gerencia → GII (GE1) → GE2 → GE3
  set: detail_jerarquico_6niveles {
    fields: [
      nom_direccion,
      nom_subdireccion,
      nom_gerencia,
      gii,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3
    ]
  }

  # ---- Set de detalle plano (sin bloque MERCADO) ----
  set: detail {
    fields: [
      nom_direccion,
      nom_subdireccion,
      nom_gerencia,
      gii,
      nom_grupo_estadistico2,
      nom_grupo_estadistico3,
      nom_zona,
      nom_estado,
      nom_canal,
      nombre_periodo_mostrar,
      mes,
      anio,
      semana,
      pedidos_ton,
      precio_deuda_total,
      deuda_total,
      deuda_libre,
      deuda_autofleteo,
      deuda_mes_resto,
      deuda_mes_siguiente,
      fact_ayer,
      fact_acum,
      fact_acum_importe,
      precio_destino_mn,
      pvo,
      pct_pvo,
      bp,
      pct_bp,
      fact_acum_2025,
      fact_acum_2026
    ]
  }
}

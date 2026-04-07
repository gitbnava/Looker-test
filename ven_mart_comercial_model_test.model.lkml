connection: "conn_datahub-deacero_mart-comercial"
connection: "conn_datahub-deacero_mart-comercial"

include: "/**/*.view"
#include: "/dashboards/bu_aceros/**/*.dashboard.lookml"
#include: "*.dashboard.lookml"

explore: ven_mart_comercial {
  label: "Comercial"

}

# Explore auxiliar oculto para sugerencias de nombre_periodo_mostrar (2022-2026)
explore: ven_mart_comercial_periodos {
  hidden: yes
  from: ven_mart_comercial
  sql_always_where: SAFE_CAST(anio AS INT64) >= 2022 AND SAFE_CAST(anio AS INT64) <= 2026 ;;
}

explore: precios_importacion {
  label: "Precios de importacion"
}

explore: cuadrante_izquierdo_superior {
  label: "Cuadrante Superior Izquierdo"
}

explore: cuadrante_superior_derecha {
  label: "Cuadrante Superior Derecha"
}

explore: cuadrante_izquierdo_inferior {
  label: "Cuadrante Inferior Izquierda"
}

explore: cuadrante_derecho_inferior {
  label: "Cuadrante Inferior Derecha"
}

map_layer: mexico_states {
  url: "https://gist.githubusercontent.com/diegovalle/5129746/raw/c1c35e439b1d5e688bca20b79f0e53a1fc12bf9e/mx_tj.json"
  property_key: "state_name"
}

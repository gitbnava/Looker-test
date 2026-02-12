connection: "conn_datahub-deacero_mart-comercial"
connection: "conn_datahub-deacero_mart-comercial"

include: "/**/*.view"
#include: "/dashboards/bu_aceros/**/*.dashboard.lookml"
#include: "*.dashboard.lookml"

explore: ven_mart_comercial {
  label: "Comercial"

}

explore: kpi_volumen_facturacion {
  label: "volumen_facturacion"
}

explore: kpi_precio_facturacion {
  label: "precio_facturacion"
}
# explore: precios_importacion {
#   label: "Precios de importacion"
# }

# explore: cuadrante_izquierdo_superior {
#   label: "Cuadrante Superior Izquierdo"
# }

# explore: cuadrante_superior_derecha {
#   label: "Cuadrante Superior Derecha"
# }

# explore: cuadrante_izquierdo_inferior {
#   label: "Cuadrante Inferior Izquierda"
# }

# map_layer: mexico_states {
#   url: "https://gist.githubusercontent.com/diegovalle/5129746/raw/c1c35e439b1d5e688bca20b79f0e53a1fc12bf9e/mx_tj.json"
#   property_key: "state_name"
# }

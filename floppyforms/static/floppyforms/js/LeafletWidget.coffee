class LeafletWKT
  
  constructor: () ->

  toLayer: (wkt) ->
    # Convert (E)WKT to LeafletLayer
    console.log wkt

  toWKT: (layer) ->
    # Convert a layer or layergroup to (E)WKT
    if layer._layers
      console.log layer._layers
    else
      console.log layer


class LeafletWidget
  
  constructor: (@options) ->
    console.log @options
    @map = new L.Map(@options.id)
    layerUrl = @options.url
    @layer = new L.TileLayer(layerUrl, {minZoom: 1});
    @marker_group = new L.LayerGroup()

    @map.setView(new L.LatLng(0, 0), 1)
    @map.addLayer(@layer)
    @map.addLayer(@marker_group)
    @map.on 'click', @mapClick

  clearFeatures: ->
    console.log "Clear"

  mapClick: (e) =>
      if not @options.is_collection
        @marker_group.clearLayers()
      marker = new L.Marker(e.latlng)
      @marker_group.addLayer(marker)

  getEWKT: (feature) ->
    wkt = new LeafletWKT().toWKT(@marker_group)
  	#return "SRID=" + @options.map_srid + ";" + @wkt_f.write(feat);

window.floppyforms = window.floppyforms or {}
window.floppyforms.LeafletWidget = LeafletWidget

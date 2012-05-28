class LeafletWidget

  constructor: (@options) ->
    @map = new L.Map(@options.map_id)
    @textarea = document.getElementById("#{ @options.id }")
    @clear = document.getElementById("#{ @options.id }_clear")
    @undo = document.getElementById("#{ @options.id }_undo")

    @geojson = @getJSON()

    layerUrl = @options.url
    @layer = new L.TileLayer(layerUrl, {minZoom: 1})
    @map.setView(new L.LatLng(0, 0), 1)
    @map.addLayer(@layer)

    @marker_group = new L.GeoJSON()
    @map.addLayer(@marker_group)
    @refreshLayer()

    @map.on 'click', @mapClick
    @clear.onclick = @clearFeatures
    @undo.onclick = @undoChange

  getJSON: =>
    # get json or
      if @textarea.value
        JSON.parse(@textarea.value)
      else
        type: @options.geom_type
        coordinates: []

  refreshLayer: ->
    @textarea.value = JSON.stringify(@geojson)
    @marker_group.clearLayers()
    if @geojson.coordinates.length > 0
      @marker_group.addGeoJSON(@geojson)
#      @marker_group.on('click', @featureClick)

  clearFeatures: =>
    @undo_geojson = @getJSON()
    @geojson =
      type: @options.geom_type
      coordinates: []
    @refreshLayer()

  undoChange: =>
    @geojson = @undo_geojson
    @refreshLayer()

  doPoint: (e, add) =>
    if add
      @geojson.coordinates = [e.latlng.lng, e.latlng.lat]
    else
      @geojson.coordinates = []
    # handle click for a point geom

  doMultiPoint: (e, add) =>
    # handle click for a multipoint geom
    point = [e.latlng.lng, e.latlng.lat]
    if add
      @geojson.coordinates.push point
    else
      index = @geojson.coordinates.indexOf(point)
      @geojson.coordinates.splice(index, 1)

  doLine: (e, add) =>
    # handle click for a line geom
    @doMultiPoint e, add

  doMultiLine: (e, add) =>
    # handle click for a multiline geom

  doPoly: (e, add) =>
    # handle click for a poly geom
    # Naive implementation for now....
    point = [e.latlng.lng, e.latlng.lat]
    if add
      @geojson.coordinates[0] ?= []
      last = @geojson.coordinates[0].pop()

      @geojson.coordinates[0].push point
      if last
        if @geojson.coordinates[0][0] == point
          @geojson.coordinates[0].unshift(last)
        @geojson.coordinates[0].push last

  doMultiPoly: (e, add) =>
    # handle click for a multipoly geom

  mapClick: (e) =>
    @undo_geojson = @getJSON()
    switch @options.geom_type
      when "Point" then @doPoint e, yes
      when "MultiPoint" then @doMultiPoint e, yes
      when "LineString" then @doLine e, yes
      when "MultiLineString" then @doMultiLine e, yes
      when "Polygon" then @doPoly e, yes
      when "MultiPolygon" then @doMultiPoly e, yes
    @refreshLayer()

  featureClick: (e) =>
    # not really sure why, but this gives us a layer.
    # Previously, I have used this and it has returned the actual marker.
    # but that was from a featurecollection rather than a simple geoJSON
    # object. Not sure how to do this...
    return
    @undo_geojson = @getJSON()
    switch @options.geom_type
      when "Point" then @doPoint e, no
      when "MultiPoint" then @doMultiPoint e, no
      when "LineString" then @doLine e, no
      when "MultiLineString" then @doMultiLine e, no
      when "Polygon" then @doPoly e, no
      when "MultiPolygon" then @doMultiPoly e, no
    @refreshLayer()

window.floppyforms = window.floppyforms or {}
window.floppyforms.LeafletWidget = LeafletWidget

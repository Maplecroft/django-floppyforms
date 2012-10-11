class LeafletWidget

  constructor: (@options) ->
    @$ = $ or django.jQuery
    @map = new L.Map(@options.map_id)
    @textarea = @$("##{ @options.id }")
    @clear = @$("##{ @options.id }_clear")
    @undo = @$("##{ @options.id }_undo")
    @redo = @$("##{ @options.id }_redo")
    @search = @$("##{ @options.id }_search")
    @searchBtn = @$("##{ @options.id }_searchBtn")
    @results = @$("##{ options.id }_search_result")

    @searchURL = "http://ws.geonames.org/searchJSON?q={{LOCATION}}&maxRows=100"

    @undo_geojson = []
    @redo_geojson = []
    @geojson = @getJSON()

    osmUrl = @options.url
    @osm = new L.TileLayer(osmUrl, {minZoom: 1})
    @ggl_sat = new L.Google('SATELLITE');
    @ggl_road = new L.Google('ROADMAP');
    @ggl_hy = new L.Google('HYBRID');
    @map.addLayer(@ggl_hy)

    @map.addControl(new L.Control.Layers({
        'Hybrid': this.ggl_hy,
        'Street': this.ggl_road,
        'Sat': this.ggl_sat,
        'OSM': this.osm}, {}));

    @map.setView(new L.LatLng(0, 0), 1)

    @marker_group = new L.GeoJSON(@geojson)
    @map.addLayer(@marker_group)

    @zoomToFit()
    @refreshLayer()

    @map.on 'click', @mapClick
    @clear.bind('click', @clearFeatures)
    @undo.bind('click', @undoChange)
    @redo.bind('click', @redoChange)
    @search.bind('keypress', @searchKeyPress)
    @searchBtn.bind('click', @findLocations)

  zoomToFit: =>
    coords = @geojson.coordinates
    if coords and coords.length > 0
      northEast = new L.LatLng(coords[0][1], coords[0][0])
      southWest = new L.LatLng(coords[0][1], coords[0][0])
      for coord in coords
        if coord[1] > northEast.lat
          northEast.lat = coord[1]
        if coord[0] > northEast.lng
          northEast.lng = coord[0]
        if coord[1] < southWest.lat
          southWest.lat = coord[1]
        if coord[0] < southWest.lng
          southWest.lng = coord[0]
      bounds = new L.LatLngBounds(southWest, northEast)
      @map.fitBounds(bounds)

  getJSON: =>
    # get json or
    if @textarea.val()
      JSON.parse(@textarea.val())
    else
      type: @options.geom_type
      coordinates: []

  refreshLayer: ->
    @textarea.val(JSON.stringify(@geojson))
    @marker_group.clearLayers()
    if @geojson and @geojson.coordinates.length > 0
      @marker_group.addData(@geojson).addTo(@map)

  clearFeatures: =>
    @undo_geojson.push(@getJSON())

    @geojson =
      type: @options.geom_type
      coordinates: []
    @refreshLayer()

    return no

  undoChange: =>
    _geojson = @undo_geojson.pop()

    if not _geojson
      return no

    @redo_geojson.push(@geojson)
    @geojson = _geojson
    @refreshLayer()

    return no

  redoChange: =>
    _geojson = @redo_geojson.pop()

    if not _geojson
      return no

    @undo_geojson.push(@geojson)
    @geojson = _geojson
    @refreshLayer()

    return no

  searchKeyPress: (e) =>
    if e.keyCode == 13
      @findLocations()
      return no

  foundLocations: (data) =>
    @results.html("")
    self = @
    for geoname in data.geonames
      item = @$("<li>[#{ geoname.countryCode }] #{ geoname.name }</li>")
      item
        .data('lat', geoname.lat)
        .data('lng', geoname.lng)
        .addClass('result')
        .attr('title', JSON.stringify(geoname))
      item.click ->
        item = self.$(@)
        self.undo_geojson.push(self.getJSON())
        self.geojson.coordinates.push([item.data('lng'), item.data('lat')])
        self.zoomToFit()
        self.refreshLayer()
        self.results.parent().fadeOut()
        self.search.val('')

      item.hover ->
        item = self.$(@)
        point = new L.LatLng(item.data('lat'), item.data('lng'))
        if not item.data('marker')
          marker = new L.Marker(point)
          item.data('marker', marker)
        else
          marker = item.data('marker')
        self.map.addLayer(marker)
        if not self.map.getBounds().contains(point)
          bounds = new L.LatLngBounds(point, self.map.getCenter())
          self.map.fitBounds(bounds)
      , ->
        item = self.$(@)
        marker = item.data('marker')
        self.map.removeLayer(marker)

      @results.append(item)
    @results.parent().show()

  findLocations: =>
    term = @search.val()
    url = @searchURL.replace('{{LOCATION}}', encodeURIComponent(term))
    self = @
    @$.ajax url,
      dataType: 'jsonp'
      success: @foundLocations

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
    @undo_geojson.push(@getJSON())
    switch @options.geom_type
      when "Point" then @doPoint e, yes
      when "MultiPoint" then @doMultiPoint e, yes
      when "LineString" then @doLine e, yes
      when "MultiLineString" then @doMultiLine e, yes
      when "Polygon" then @doPoly e, yes
      when "MultiPolygon" then @doMultiPoly e, yes
    @refreshLayer()

window.floppyforms = window.floppyforms or {}
window.floppyforms.LeafletWidget = LeafletWidget

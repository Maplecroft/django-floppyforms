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

    @places_search_input = document.getElementById('g_places_search')
    @autocomplete = new google.maps.places.Autocomplete(
      @places_search_input, {}) #types: ['(regions)']})
    google.maps.event.addListener(
      @autocomplete, 'place_changed', @doPlaceChanged)

    # This prevents any containing form from being submitted if the
    # user hits enter having selected an autocompletion search choice.
    google.maps.event.addDomListener(@places_search_input, 'keydown', (e) -> 
      if e.keyCode == 13
        if e.preventDefault
          e.preventDefault()
        else
          # Since the google event handler framework does not handle 
          # early IE versions, we have to do it by our self. :-( 
          e.cancelBubble = true
          e.returnValue = false
    )

    ButtonsControl = L.Control.extend(
      options: position: 'bottomleft'
      onAdd: @doOnAdd
    )

    @map.addControl(new ButtonsControl())
    @showHideControls()  

  doOnAdd: (map) =>
    # create the control container with a particular class name
    container = L.DomUtil.create('div', 'buttons-control')

    # Move the buttons (created in the template) into the
    # container.
    controls = document.getElementById('controls')
    container.appendChild(controls.parentNode.removeChild(controls))
    return container

  showHideControls: =>
    # Show/hide the clear/undo/redo buttons according to what's possible.
    if @undo_geojson.length > 0
      @undo.removeClass('disabled').attr('href', '#')
    else
      @undo.addClass('disabled').removeAttr('href')
    if @redo_geojson.length > 0
      @redo.removeClass('disabled').attr('href', '#')
    else
      @redo.addClass('disabled').removeAttr('href')
    if @geojson.coordinates.length > 0
      @clear.removeClass('disabled').attr('href', '#')
    else
      @clear.addClass('disabled').removeAttr('href')

  doPlaceChanged: =>
    # Called when user selects a place from the auto-suggested google
    # places.  We add the selected location to the set of points and
    # zoom appropriately to display them all.
    @undo_geojson.push(@getJSON())
    location = @autocomplete.getPlace().geometry.location
    lng_lat = [location.lng(), location.lat()]
    @geojson.coordinates.push(lng_lat)
    @showHideControls()
    @zoomToFit()
    @refreshLayer()
    @$('#g_places_search').blur().attr('value', '')

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
    @showHideControls()
    @refreshLayer()

    return no

  undoChange: =>
    _geojson = @undo_geojson.pop()
    @showHideControls()

    if not _geojson
      return no

    @redo_geojson.push(@geojson)
    @geojson = _geojson
    @showHideControls()
    # @zoomToFit()
    @refreshLayer()

    return no

  redoChange: =>
    _geojson = @redo_geojson.pop()
    @showHideControls()

    if not _geojson
      return no

    @undo_geojson.push(@geojson)
    @geojson = _geojson
    @showHideControls()
    # @zoomToFit()
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
    @showHideControls()   
    # handle click for a point geom

  doMultiPoint: (e, add) =>
    # handle click for a multipoint geom
    point = [e.latlng.lng, e.latlng.lat]
    if add
      @geojson.coordinates.push point
    else
      index = @geojson.coordinates.indexOf(point)
      @geojson.coordinates.splice(index, 1)
    @showHideControls()  

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
    @showHideControls()    

  doMultiPoly: (e, add) =>
    # handle click for a multipoly geom

  mapClick: (e) =>
    @undo_geojson.push(@getJSON())
    @showHideControls()
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

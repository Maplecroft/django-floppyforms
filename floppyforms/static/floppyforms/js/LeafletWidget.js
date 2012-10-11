// Generated by CoffeeScript 1.3.3
(function() {
  var LeafletWidget,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  var ButtonsControl = L.Control.extend({
      options: {
	  position: 'bottomleft'
      },

      onAdd: function (map) {
	  // create the control container with a particular class name
	  var container = L.DomUtil.create('div', 'buttons-control');

	  // Move the buttons (created in the template) into the
	  // container.
          var controls = document.getElementById('controls');
	  container.appendChild(controls.parentNode.removeChild(controls));
	  return container;
      }
  });

  LeafletWidget = (function() {

    function LeafletWidget(options) {
      var osmUrl;
      this.options = options;
      this.mapClick = __bind(this.mapClick, this);

      this.doMultiPoly = __bind(this.doMultiPoly, this);

      this.doPoly = __bind(this.doPoly, this);

      this.doMultiLine = __bind(this.doMultiLine, this);

      this.doLine = __bind(this.doLine, this);

      this.doMultiPoint = __bind(this.doMultiPoint, this);

      this.doPoint = __bind(this.doPoint, this);

      this.findLocations = __bind(this.findLocations, this);

      this.foundLocations = __bind(this.foundLocations, this);

      this.searchKeyPress = __bind(this.searchKeyPress, this);

      this.redoChange = __bind(this.redoChange, this);

      this.undoChange = __bind(this.undoChange, this);

      this.clearFeatures = __bind(this.clearFeatures, this);

      this.getJSON = __bind(this.getJSON, this);

      this.zoomToFit = __bind(this.zoomToFit, this);

      this.$ = $ || django.jQuery;
      this.map = new L.Map(this.options.map_id);
      this.textarea = this.$("#" + this.options.id);
      this.clear = this.$("#" + this.options.id + "_clear");
      this.undo = this.$("#" + this.options.id + "_undo");
      this.redo = this.$("#" + this.options.id + "_redo");
      this.search = this.$("#" + this.options.id + "_search");
      this.searchBtn = this.$("#" + this.options.id + "_searchBtn");
      this.results = this.$("#" + options.id + "_search_result");
      this.searchURL = "http://ws.geonames.org/searchJSON?q={{LOCATION}}&maxRows=100";
      this.undo_geojson = [];
      this.redo_geojson = [];
      this.geojson = this.getJSON();
      osmUrl = this.options.url;
      this.osm = new L.TileLayer(osmUrl, {
        minZoom: 1
      });
      this.ggl_sat = new L.Google('SATELLITE');
      this.ggl_road = new L.Google('ROADMAP');
      this.ggl_hy = new L.Google('HYBRID');
      this.map.addLayer(this.ggl_hy);
      this.map.addControl(new L.Control.Layers({
        'Hybrid': this.ggl_hy,
        'Street': this.ggl_road,
        'Sat': this.ggl_sat,
        'OSM': this.osm
      }, {}));

      this.map.addControl(new ButtonsControl());

      this.map.setView(new L.LatLng(0, 0), 1);
      this.marker_group = new L.GeoJSON(this.geojson);
      this.map.addLayer(this.marker_group);
      this.zoomToFit();
      this.refreshLayer();
      this.map.on('click', this.mapClick);
      this.clear.bind('click', this.clearFeatures);
      this.undo.bind('click', this.undoChange);
      this.redo.bind('click', this.redoChange);
      this.search.bind('keypress', this.searchKeyPress);
      this.searchBtn.bind('click', this.findLocations);
    }

    LeafletWidget.prototype.zoomToFit = function() {
      var bounds, coord, coords, northEast, southWest, _i, _len;
      coords = this.geojson.coordinates;
      if (coords && coords.length > 0) {
        northEast = new L.LatLng(coords[0][1], coords[0][0]);
        southWest = new L.LatLng(coords[0][1], coords[0][0]);
        for (_i = 0, _len = coords.length; _i < _len; _i++) {
          coord = coords[_i];
          if (coord[1] > northEast.lat) {
            northEast.lat = coord[1];
          }
          if (coord[0] > northEast.lng) {
            northEast.lng = coord[0];
          }
          if (coord[1] < southWest.lat) {
            southWest.lat = coord[1];
          }
          if (coord[0] < southWest.lng) {
            southWest.lng = coord[0];
          }
        }
        bounds = new L.LatLngBounds(southWest, northEast);
        return this.map.fitBounds(bounds);
      }
    };

    LeafletWidget.prototype.getJSON = function() {
      if (this.textarea.val()) {
        return JSON.parse(this.textarea.val());
      } else {
        return {
          type: this.options.geom_type,
          coordinates: []
        };
      }
    };

    LeafletWidget.prototype.refreshLayer = function() {
      this.textarea.val(JSON.stringify(this.geojson));
      this.marker_group.clearLayers();
      if (this.geojson && this.geojson.coordinates.length > 0) {
        return this.marker_group.addData(this.geojson).addTo(this.map);
      }
    };

    LeafletWidget.prototype.clearFeatures = function() {
      this.undo_geojson.push(this.getJSON());
      this.geojson = {
        type: this.options.geom_type,
        coordinates: []
      };
      this.refreshLayer();
      return false;
    };

    LeafletWidget.prototype.undoChange = function() {
      var _geojson;
      _geojson = this.undo_geojson.pop();
      if (!_geojson) {
        return false;
      }
      this.redo_geojson.push(this.geojson);
      this.geojson = _geojson;
      this.refreshLayer();
      return false;
    };

    LeafletWidget.prototype.redoChange = function() {
      var _geojson;
      _geojson = this.redo_geojson.pop();
      if (!_geojson) {
        return false;
      }
      this.undo_geojson.push(this.geojson);
      this.geojson = _geojson;
      this.refreshLayer();
      return false;
    };

    LeafletWidget.prototype.searchKeyPress = function(e) {
      if (e.keyCode === 13) {
        this.findLocations();
        return false;
      }
    };

    LeafletWidget.prototype.foundLocations = function(data) {
      var geoname, item, self, _i, _len, _ref;
      this.results.html("");
      self = this;
      _ref = data.geonames;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        geoname = _ref[_i];
        item = this.$("<li>[" + geoname.countryCode + "] " + geoname.name + "</li>");
        item.data('lat', geoname.lat).data('lng', geoname.lng).addClass('result').attr('title', JSON.stringify(geoname));
        item.click(function() {
          item = self.$(this);
          self.undo_geojson.push(self.getJSON());
          self.geojson.coordinates.push([item.data('lng'), item.data('lat')]);
          self.zoomToFit();
          self.refreshLayer();
          self.results.parent().fadeOut();
          return self.search.val('');
        });
        item.hover(function() {
          var bounds, marker, point;
          item = self.$(this);
          point = new L.LatLng(item.data('lat'), item.data('lng'));
          if (!item.data('marker')) {
            marker = new L.Marker(point);
            item.data('marker', marker);
          } else {
            marker = item.data('marker');
          }
          self.map.addLayer(marker);
          if (!self.map.getBounds().contains(point)) {
            bounds = new L.LatLngBounds(point, self.map.getCenter());
            return self.map.fitBounds(bounds);
          }
        }, function() {
          var marker;
          item = self.$(this);
          marker = item.data('marker');
          return self.map.removeLayer(marker);
        });
        this.results.append(item);
      }
      return this.results.parent().show();
    };

    LeafletWidget.prototype.findLocations = function() {
      var self, term, url;
      term = this.search.val();
      url = this.searchURL.replace('{{LOCATION}}', encodeURIComponent(term));
      self = this;
      return this.$.ajax(url, {
        dataType: 'jsonp',
        success: this.foundLocations
      });
    };

    LeafletWidget.prototype.doPoint = function(e, add) {
      if (add) {
        return this.geojson.coordinates = [e.latlng.lng, e.latlng.lat];
      } else {
        return this.geojson.coordinates = [];
      }
    };

    LeafletWidget.prototype.doMultiPoint = function(e, add) {
      var index, point;
      point = [e.latlng.lng, e.latlng.lat];
      if (add) {
        return this.geojson.coordinates.push(point);
      } else {
        index = this.geojson.coordinates.indexOf(point);
        return this.geojson.coordinates.splice(index, 1);
      }
    };

    LeafletWidget.prototype.doLine = function(e, add) {
      return this.doMultiPoint(e, add);
    };

    LeafletWidget.prototype.doMultiLine = function(e, add) {};

    LeafletWidget.prototype.doPoly = function(e, add) {
      var last, point, _base, _ref;
      point = [e.latlng.lng, e.latlng.lat];
      if (add) {
        if ((_ref = (_base = this.geojson.coordinates)[0]) == null) {
          _base[0] = [];
        }
        last = this.geojson.coordinates[0].pop();
        this.geojson.coordinates[0].push(point);
        if (last) {
          if (this.geojson.coordinates[0][0] === point) {
            this.geojson.coordinates[0].unshift(last);
          }
          return this.geojson.coordinates[0].push(last);
        }
      }
    };

    LeafletWidget.prototype.doMultiPoly = function(e, add) {};

    LeafletWidget.prototype.mapClick = function(e) {
      this.undo_geojson.push(this.getJSON());
      switch (this.options.geom_type) {
        case "Point":
          this.doPoint(e, true);
          break;
        case "MultiPoint":
          this.doMultiPoint(e, true);
          break;
        case "LineString":
          this.doLine(e, true);
          break;
        case "MultiLineString":
          this.doMultiLine(e, true);
          break;
        case "Polygon":
          this.doPoly(e, true);
          break;
        case "MultiPolygon":
          this.doMultiPoly(e, true);
      }
      return this.refreshLayer();
    };

    return LeafletWidget;

  })();

  window.floppyforms = window.floppyforms || {};

  window.floppyforms.LeafletWidget = LeafletWidget;

}).call(this);

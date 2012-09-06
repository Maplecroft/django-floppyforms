from django.conf import settings
from django.utils import translation

try:
    from django.contrib.gis import gdal, geos
except ImportError:
    """GDAL / GEOS not installed"""

import floppyforms as forms

__all__ = ('GeometryWidget', 'GeometryCollectionWidget',
           'PointWidget', 'MultiPointWidget',
           'LineStringWidget', 'MultiLineStringWidget',
           'PolygonWidget', 'MultiPolygonWidget',
           'BaseGeometryWidget', 'BaseMetacartaWidget',
           'BaseOsmWidget', 'BaseGMapWidget',
           'BaseLeafletWidget',)


class BaseGeometryWidget(forms.Textarea):
    """
    The base class for rich geometry widgets. Custom widgets may be
    obtained by subclassing this base widget.
    """
    display_wkt = False
    map_width = 600
    map_height = 400
    map_srid = 4326
    template_name = 'floppyforms/gis/openlayers.html'

    # Internal API #
    is_point = False
    is_linestring = False
    is_polygon = False
    is_collection = False
    geom_type = 'GEOMETRY'

    map_attrs = (
        'map_width', 'map_height', 'map_srid', 'display_wkt', 'as_geojson',
    )

    def __init__(self, *args, **kwargs):
        super(BaseGeometryWidget, self).__init__(*args, **kwargs)
        attrs = kwargs.pop('attrs', {})
        for key in self.map_attrs:
            setattr(self, key, attrs.pop(key, getattr(self, key)))

    def get_context_data(self):
        ctx = super(BaseGeometryWidget, self).get_context_data()
        for key in ('is_polygon', 'is_linestring',
                    'is_point', 'is_collection'):
            ctx[key] = getattr(self, key)
        ctx['geom_type'] = gdal.OGRGeomType(self.geom_type)

        for key in self.map_attrs:
            ctx[key] = getattr(self, key)

        if self.geom_type == 'GEOMETRYCOLLECTION':
            ctx['geom_type'] = 'Collection'
        return ctx

    def get_context(self, name, value, attrs=None, extra_context={}):
        # If a string reaches here (via a validation error on another
        # field) then just reconstruct the Geometry.
        if isinstance(value, basestring):
            try:
                value = geos.GEOSGeometry(value)
            except (geos.GEOSException, ValueError):
                value = None

        if (value and
            value.geom_type.upper() != self.geom_type and
            self.geom_type != 'GEOMETRY'):
            value = None

        # Defaulting the WKT value to a blank string
        wkt = ''
        geojson = ''
        if value:
            srid = self.map_srid
            if value.srid != srid:
                try:
                    ogr = value.ogr
                    ogr.transform(srid)
                    wkt = ogr.wkt
                    geojson = ogr.geojson
                except gdal.OGRException:
                    pass  # wkt left as an empty string
            else:
                wkt = value.wkt
                geojson = value.geojson
        if hasattr(self, 'as_geojson') and self.as_geojson:
            context = super(BaseGeometryWidget, self).get_context(
                name, geojson, attrs)
        else:
            context = super(BaseGeometryWidget, self).get_context(
                name, wkt, attrs)
        context['module'] = 'map_%s' % name.replace('-', '_')
        context['name'] = name
        # Django >= 1.4 doesn't have ADMIN_MEDIA_PREFIX anymore, we must
        # rely on contrib.staticfiles.
        if hasattr(settings, 'ADMIN_MEDIA_PREFIX'):
            context['ADMIN_MEDIA_PREFIX'] = settings.ADMIN_MEDIA_PREFIX
        else:
            context['ADMIN_MEDIA_PREFIX'] = settings.STATIC_URL + 'admin/'
        context['LANGUAGE_BIDI'] = translation.get_language_bidi()
        return context

    def render(self, name, value, attrs=None):
        _value = value
        print _value
        return super(BaseGeometryWidget, self).render(name, _value, attrs)


class GeometryWidget(BaseGeometryWidget):
    pass


class GeometryCollectionWidget(GeometryWidget):
    is_collection = True
    geom_type = 'GEOMETRYCOLLECTION'


class PointWidget(BaseGeometryWidget):
    is_point = True
    geom_type = 'POINT'


class MultiPointWidget(PointWidget):
    is_collection = True
    geom_type = 'MULTIPOINT'


class LineStringWidget(BaseGeometryWidget):
    is_linestring = True
    geom_type = 'LINESTRING'


class MultiLineStringWidget(LineStringWidget):
    is_collection = True
    geom_type = 'MULTILINESTRING'


class PolygonWidget(BaseGeometryWidget):
    is_polygon = True
    geom_type = 'POLYGON'


class MultiPolygonWidget(PolygonWidget):
    is_collection = True
    geom_type = 'MULTIPOLYGON'


class BaseLeafletWidget(BaseGeometryWidget):
    """A Leaflet base widget"""
    map_srid = 4326
    template_name = 'floppyforms/gis/leaflet.html'
    as_geojson = True

    class Media:
        js = (
            'http://cdn.leafletjs.com/leaflet-0.4/leaflet.js',
            'floppyforms/js/LeafletWidget.js',
        )
        css = ({
            'all': (
                'http://cdn.leafletjs.com/leaflet-0.4/leaflet.css',
            )
        })


class BaseMetacartaWidget(BaseGeometryWidget):

    class Media:
        js = (
            'http://openlayers.org/api/2.10/OpenLayers.js',
            'floppyforms/js/MapWidget.js',
        )


class BaseOsmWidget(BaseGeometryWidget):
    """An OpenStreetMap base widget"""
    map_srid = 900913
    template_name = 'floppyforms/gis/osm.html'

    class Media:
        js = (
            'http://openlayers.org/api/2.10/OpenLayers.js',
            'http://www.openstreetmap.org/openlayers/OpenStreetMap.js',
            'floppyforms/js/MapWidget.js',
        )


class BaseGMapWidget(BaseGeometryWidget):
    """A Google Maps base widget"""
    map_srid = 900913
    template_name = 'floppyforms/gis/google.html'

    class Media:
        js = (
            'http://openlayers.org/dev/OpenLayers.js',  # FIXME: use 2.11
                                                        # when it's out
            'floppyforms/js/MapWidget.js',
            'http://maps.google.com/maps/api/js?sensor=false',
        )

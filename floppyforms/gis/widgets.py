from django.conf import settings
from django.utils import translation, six

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


def _google_api_args():
    m = {'sensor': 'false', 'libraries': 'places'}

    # If not in DEBUG mode, and GOOGLE_MAPS_API_CLIENT_ID setting is
    # defined, use it as client_id when loading the googleapis
    # library.  If you stick a ! at the start of
    # GOOGLE_MAPS_API_CLIENT_ID it will be used even in DEBUG mode.
    raw_client_id = getattr(settings, 'GOOGLE_MAPS_API_CLIENT_ID', None)
    if (raw_client_id
        and (not getattr(settings, 'DEBUG') or raw_client_id.startswith('!'))):
        client_id = raw_client_id.lstrip('!')
    else:
        client_id = None
    if client_id:
        m['client'] = client_id

    return m


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
        'mapquest_token', 'map_ids', 'primary_map',
    )

    def __init__(self, *args, **kwargs):
        super(BaseGeometryWidget, self).__init__(*args, **kwargs)
        attrs = kwargs.pop('attrs', {})
        setattr(self, 'map_ids', getattr(self, 'map_ids', None))
        for key in self.map_attrs:
            setattr(self, key, attrs.pop(key, getattr(self, key, None)))

    def get_context_data(self):
        ctx = super(BaseGeometryWidget, self).get_context_data()
        for key in ('is_polygon', 'is_linestring',
                    'is_point', 'is_collection'):
            ctx[key] = getattr(self, key)
        ctx['geom_type'] = gdal.OGRGeomType(self.geom_type)

        for key in self.map_attrs:
            ctx[key] = getattr(self, key, None)

        if self.geom_type == 'GEOMETRYCOLLECTION':
            ctx['geom_type'] = 'Collection'
        return ctx

    def get_context(self, name, value, attrs=None, extra_context={}):
        # If a string reaches here (via a validation error on another
        # field) then just reconstruct the Geometry.
        if isinstance(value, six.text_type):
            try:
                value = geos.GEOSGeometry(value)
            except (geos.GEOSException, ValueError):
                value = None

        if (
            value and value.geom_type.upper() != self.geom_type and
            self.geom_type != 'GEOMETRY'
        ):
            value = None

        # Defaulting the WKT value to a blank string
        wkt = ''
        geojson = ''
        if value:
            srid = self.map_srid
            if not value.srid:
                # If we're processing a form with errors, for some reason the
                # SRID doesn't get set on the value, and the below
                # ogr.transform always throws an exception (presumably because
                # you can't transform from no SRID to self.map_srid). This just
                # assumes it /should/ have been set the same as self.map_srid
                # and proceeds appropriately.
                ogr = value.ogr
                value.srid = srid
                wkt = ogr.wkt
                geojson = ogr.geojson
            elif value.srid != srid:
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
            'floppyforms/js/LeafletWidget.js',
            'https://unpkg.com/leaflet@1.2.0/dist/leaflet-src.js',
            'https://api.mqcdn.com/sdk/mapquest-js/v1.2.0/mapquest-core.js',
        )
        css = ({
            'all': (
                'https://unpkg.com/leaflet@1.2.0/dist/leaflet.css',
                'https://api.mqcdn.com/sdk/mapquest-js/v1.2.0/mapquest-maps.css',
            )
        })


class BaseMetacartaWidget(BaseGeometryWidget):

    class Media:
        js = (
            'https://openlayers.org/api/OpenLayers.js',
            'floppyforms/js/MapWidget.js',
        )


class BaseOsmWidget(BaseGeometryWidget):
    """An OpenStreetMap base widget"""
    map_srid = 900913
    template_name = 'floppyforms/gis/osm.html'

    class Media:
        js = (
            'https://openlayers.org/api/OpenLayers.js',
            'https://www.openstreetmap.org/openlayers/OpenStreetMap.js',
            'floppyforms/js/MapWidget.js',
        )


class BaseGMapWidget(BaseGeometryWidget):
    """A Google Maps base widget"""
    map_srid = 900913
    template_name = 'floppyforms/gis/google.html'

    class Media:
        js = (
            'https://openlayers.org/api/OpenLayers.js',
            'floppyforms/js/MapWidget.js',
            'https://maps.google.com/maps/api/js?sensor=false',
        )

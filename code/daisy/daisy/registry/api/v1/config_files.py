# Copyright 2010-2011 OpenStack Foundation
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

"""
Reference implementation registry server WSGI controller
"""

from oslo_config import cfg
from oslo_log import log as logging
from oslo_utils import strutils
from oslo_utils import timeutils
from webob import exc

from daisy.common import exception
from daisy.common import utils
from daisy.common import wsgi
import daisy.db
from daisy import i18n


LOG = logging.getLogger(__name__)
_ = i18n._
_LE = i18n._LE
_LI = i18n._LI
_LW = i18n._LW

CONF = cfg.CONF

DISPLAY_FIELDS_IN_INDEX = ['id', 'name','container_format',
                           'checksum']

SUPPORTED_FILTERS = ['name', 'container_format']

SUPPORTED_SORT_KEYS = ('name', 'container_format', 
                       'id', 'created_at', 'updated_at')

SUPPORTED_SORT_DIRS = ('asc', 'desc')

SUPPORTED_PARAMS = ('limit', 'marker', 'sort_key', 'sort_dir')


class Controller(object):

    def __init__(self):
        self.db_api = daisy.db.get_api()

    def _get_config_files(self, context, filters, **params):
        """Get config_files, wrapping in exception if necessary."""
        try:
            return self.db_api.config_file_get_all(context, filters=filters,
                                             **params)
        except exception.NotFound:
            LOG.warn(_LW("Invalid marker. Config_file %(id)s could not be "
                         "found.") % {'id': params.get('marker')})
            msg = _("Invalid marker. Config_file could not be found.")
            raise exc.HTTPBadRequest(explanation=msg)
        except exception.Forbidden:
            LOG.warn(_LW("Access denied to config_file %(id)s but returning "
                         "'not found'") % {'id': params.get('marker')})
            msg = _("Invalid marker. config_file could not be found.")
            raise exc.HTTPBadRequest(explanation=msg)
        except Exception:
            LOG.exception(_LE("Unable to get config_files"))
            raise

    def detail_config_file(self, req):
        """Return a filtered list of public, non-deleted config_files in detail

        :param req: the Request object coming from the wsgi layer
        :retval a mapping of the following form::

            dict(config_files=[config_file_list])

        Where config_file_list is a sequence of mappings containing
        all config_file model fields.
        """
        params = self._get_query_params(req)

        config_files = self._get_config_files(req.context, **params)

        return dict(config_files=config_files)

    def _get_query_params(self, req):
        """Extract necessary query parameters from http request.

        :param req: the Request object coming from the wsgi layer
        :retval dictionary of filters to apply to list of config_files
        """
        params = {
            'filters': self._get_filters(req),
            'limit': self._get_limit(req),
            'sort_key': [self._get_sort_key(req)],
            'sort_dir': [self._get_sort_dir(req)],
            'marker': self._get_marker(req),
        }

        for key, value in params.items():
            if value is None:
                del params[key]
                
        return params

    def _get_filters(self, req):
        """Return a dictionary of query param filters from the request

        :param req: the Request object coming from the wsgi layer
        :retval a dict of key/value filters
        """
        filters = {}
        properties = {}

        for param in req.params:
            if param in SUPPORTED_FILTERS:
                filters[param] = req.params.get(param)
            if param.startswith('property-'):
                _param = param[9:]
                properties[_param] = req.params.get(param)

        if 'changes-since' in filters:
            isotime = filters['changes-since']
            try:
                filters['changes-since'] = timeutils.parse_isotime(isotime)
            except ValueError:
                raise exc.HTTPBadRequest(_("Unrecognized changes-since value"))

        if 'protected' in filters:
            value = self._get_bool(filters['protected'])
            if value is None:
                raise exc.HTTPBadRequest(_("protected must be True, or "
                                           "False"))

            filters['protected'] = value

        # only allow admins to filter on 'deleted'
        if req.context.is_admin:
            deleted_filter = self._parse_deleted_filter(req)
            if deleted_filter is not None:
                filters['deleted'] = deleted_filter
            elif 'changes-since' not in filters:
                filters['deleted'] = False
        elif 'changes-since' not in filters:
            filters['deleted'] = False

        if properties:
            filters['properties'] = properties

        return filters

    def _get_limit(self, req):
        """Parse a limit query param into something usable."""
        try:
            limit = int(req.params.get('limit', CONF.limit_param_default))
        except ValueError:
            raise exc.HTTPBadRequest(_("limit param must be an integer"))

        if limit < 0:
            raise exc.HTTPBadRequest(_("limit param must be positive"))

        return min(CONF.api_limit_max, limit)

    def _get_marker(self, req):
        """Parse a marker query param into something usable."""
        marker = req.params.get('marker', None)

        if marker and not utils.is_uuid_like(marker):
            msg = _('Invalid marker format')
            raise exc.HTTPBadRequest(explanation=msg)

        return marker

    def _get_sort_key(self, req):
        """Parse a sort key query param from the request object."""
        sort_key = req.params.get('sort_key', 'created_at')
        if sort_key is not None and sort_key not in SUPPORTED_SORT_KEYS:
            _keys = ', '.join(SUPPORTED_SORT_KEYS)
            msg = _("Unsupported sort_key. Acceptable values: %s") % (_keys,)
            raise exc.HTTPBadRequest(explanation=msg)
        return sort_key

    def _get_sort_dir(self, req):
        """Parse a sort direction query param from the request object."""
        sort_dir = req.params.get('sort_dir', 'desc')
        if sort_dir is not None and sort_dir not in SUPPORTED_SORT_DIRS:
            _keys = ', '.join(SUPPORTED_SORT_DIRS)
            msg = _("Unsupported sort_dir. Acceptable values: %s") % (_keys,)
            raise exc.HTTPBadRequest(explanation=msg)
        return sort_dir

    def _get_bool(self, value):
        value = value.lower()
        if value == 'true' or value == '1':
            return True
        elif value == 'false' or value == '0':
            return False

        return None

    def _parse_deleted_filter(self, req):
        """Parse deleted into something usable."""
        deleted = req.params.get('deleted')
        if deleted is None:
            return None
        return strutils.bool_from_string(deleted)

    @utils.mutating
    def add_config_file(self, req, body):
        """Registers a new config_file with the registry.

        :param req: wsgi Request object
        :param body: Dictionary of information about the config_file

        :retval Returns the newly-created config_file information as a mapping,
                which will include the newly-created config_file's internal id
                in the 'id' field
        """
        
        config_file_data = body["config_file"]

        config_file_id = config_file_data.get('id')
        
        if config_file_id and not utils.is_uuid_like(config_file_id):
            msg = _LI("Rejecting config_file creation request for invalid config_file "
                      "id '%(bad_id)s'") % {'bad_id': config_file_id}
            LOG.info(msg)
            msg = _("Invalid config_file id format")
            return exc.HTTPBadRequest(explanation=msg)

        try:
            config_file_data = self.db_api.config_file_add(req.context, config_file_data)
        
            msg = (_LI("Successfully created config_file %s") %
                   config_file_data["id"])
            LOG.info(msg)
            if 'config_file' not in config_file_data:
                config_file_data = dict(config_file=config_file_data)
            return config_file_data
        except exception.Duplicate:
            msg = _("config_file with identifier %s already exists!") % config_file_id
            LOG.warn(msg)
            return exc.HTTPConflict(msg)
        except exception.Invalid as e:
            msg = (_("Failed to add config_file metadata. "
                     "Got error: %s") % utils.exception_to_str(e))
            LOG.error(msg)
            return exc.HTTPBadRequest(msg)
        except Exception:
            LOG.exception(_LE("Unable to create config_file %s"), config_file_id)
            raise

    @utils.mutating
    def delete_config_file(self, req, id):
        """Deletes an existing config_file with the registry.

        :param req: wsgi Request object
        :param id:  The opaque internal identifier for the image

        :retval Returns 200 if delete was successful, a fault if not. On
        success, the body contains the deleted image information as a mapping.
        """
        try:
            deleted_config_file = self.db_api.config_file_destroy(req.context, id)
            msg = _LI("Successfully deleted config_file %(id)s") % {'id': id}
            LOG.info(msg)
            return dict(config_file=deleted_config_file)
        except exception.ForbiddenPublicImage:
            msg = _LI("Delete denied for public config_file %(id)s") % {'id': id}
            LOG.info(msg)
            raise exc.HTTPForbidden()
        except exception.Forbidden:
            # If it's private and doesn't belong to them, don't let on
            # that it exists
            msg = _LI("Access denied to config_file %(id)s but returning"
                      " 'not found'") % {'id': id}
            LOG.info(msg)
            return exc.HTTPNotFound()
        except exception.NotFound:
            msg = _LI("config_file %(id)s not found") % {'id': id}
            LOG.info(msg)
            return exc.HTTPNotFound()
        except Exception:
            LOG.exception(_LE("Unable to delete config_file %s") % id)
            raise

    @utils.mutating
    def get_config_file(self, req, id):
        """Return data about the given config_file id."""
        try:
            config_file_data = self.db_api.config_file_get(req.context, id)
            msg = "Successfully retrieved config_file %(id)s" % {'id': id}
            LOG.debug(msg)
        except exception.NotFound:
            msg = _LI("config_file %(id)s not found") % {'id': id}
            LOG.info(msg)
            raise exc.HTTPNotFound()
        except exception.Forbidden:
            # If it's private and doesn't belong to them, don't let on
            # that it exists
            msg = _LI("Access denied to config_file %(id)s but returning"
                      " 'not found'") % {'id': id}
            LOG.info(msg)
            raise exc.HTTPNotFound()
        except Exception:
            LOG.exception(_LE("Unable to show config_file %s") % id)
            raise
        if 'config_file' not in config_file_data:
            config_file_data = dict(config_file=config_file_data)
        return config_file_data
        
    @utils.mutating
    def update_config_file(self, req, id, body):
        """Updates an existing config_file with the registry.

        :param req: wsgi Request object
        :param body: Dictionary of information about the image
        :param id:  The opaque internal identifier for the image

        :retval Returns the updated image information as a mapping,
        """
        config_file_data = body['config_file']
        try:
            updated_config_file = self.db_api.config_file_update(req.context, id, config_file_data)

            msg = _LI("Updating metadata for config_file %(id)s") % {'id': id}
            LOG.info(msg)
            if 'config_file' not in updated_config_file:
                config_file_data = dict(config_file=updated_config_file)
            return config_file_data
        except exception.Invalid as e:
            msg = (_("Failed to update config_file metadata. "
                     "Got error: %s") % utils.exception_to_str(e))
            LOG.error(msg)
            return exc.HTTPBadRequest(msg)
        except exception.NotFound:
            msg = _LI("config_file %(id)s not found") % {'id': id}
            LOG.info(msg)
            raise exc.HTTPNotFound(body='config_file not found',
                                   request=req,
                                   content_type='text/plain')
        except exception.ForbiddenPublicImage:
            msg = _LI("Update denied for config_file %(id)s") % {'id': id}
            LOG.info(msg)
            raise exc.HTTPForbidden()
        except exception.Forbidden:
            # If it's private and doesn't belong to them, don't let on
            # that it exists
            msg = _LI("Access denied to config_file %(id)s but returning"
                      " 'not found'") % {'id': id}
            LOG.info(msg)
            raise exc.HTTPNotFound(body='config_file not found',
                                   request=req,
                                   content_type='text/plain')
        except exception.Conflict as e:
            LOG.info(utils.exception_to_str(e))
            raise exc.HTTPConflict(body='config_file operation conflicts',
                                   request=req,
                                   content_type='text/plain')
        except Exception:
            LOG.exception(_LE("Unable to update config_file %s") % id)
            raise

def create_resource():
    """Images resource factory method."""
    deserializer = wsgi.JSONRequestDeserializer()
    serializer = wsgi.JSONResponseSerializer()
    return wsgi.Resource(Controller(), deserializer, serializer)

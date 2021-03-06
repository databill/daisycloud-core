#
#   Copyright ZTE
#   Daisy Tools Dashboard
#

from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt

import json

from horizon import messages
from horizon import views
from horizon import exceptions

from openstack_dashboard import api
from openstack_dashboard.dashboards.environment.cluster import net_plane \
    as cluster_net_plane
from openstack_dashboard.dashboards.environment.cluster import role \
    as cluster_role
from openstack_dashboard.dashboards.environment.deploy import deploy_rule_lib

import logging
LOG = logging.getLogger(__name__)


class ModifyView(views.HorizonTemplateView):
    template_name = "environment/cluster/modify_cluster.html"

    def get_clusters(self):
        clusters = api.daisy.cluster_list(self.request)
        cluster_lists = [c for c in clusters]
        return cluster_lists

    def get_context_data(self, **kwargs):
        context = super(ModifyView, self).get_context_data(**kwargs)
        net_planes = cluster_net_plane.\
            get_net_plane_list(self.request, self.kwargs["cluster_id"])
        context["network"] = {"networks": net_planes}
        context['cluster_id'] = self.kwargs['cluster_id']
        context['clusters'] = self.get_clusters()
        context["roles"] = cluster_role.\
            get_role_list(self.request, self.kwargs["cluster_id"])
        return context

    def get_success_url(self):
        return "/dashboard/environment/"


@csrf_exempt
def GetCluster(request):
    data = json.loads(request.body)

    filter = data["cluster_info"]
    cluster_info = api.daisy.cluster_get(request, filter["cluster_id"])

    ret_cluster_list = []
    ret_cluster_list.append({
        "id": cluster_info.id,
        "name": cluster_info.name,
        "base_mac": cluster_info.networking_parameters["base_mac"],
        "gre_id_start": cluster_info.networking_parameters["gre_id_range"][0],
        "gre_id_end": cluster_info.networking_parameters["gre_id_range"][1],
        "auto_scale": cluster_info.auto_scale,
        "use_dns": cluster_info.use_dns,
        "description": cluster_info.description})

    return HttpResponse(json.dumps(ret_cluster_list),
                        content_type="application/json")


@csrf_exempt
def GetClusters(request):
    clusters = api.daisy.cluster_list(request)
    cluster_lists = [c for c in clusters]

    ret_cluster_list = []
    for cluster in cluster_lists:
        ret_cluster_list.append({
            "id": cluster.id,
            "name": cluster.name,
            "auto_scale": cluster.auto_scale})

    return HttpResponse(json.dumps(ret_cluster_list),
                        content_type="application/json")


@csrf_exempt
def modify_submit(request, cluster_id):
    data = json.loads(request.body)
    msg = ('Cluster modify request.body::::::: %s') % request.body
    LOG.info(msg)
    cluster_info = data["cluster_info"]
    response = HttpResponse()
    try:
        # check param valid
        deploy_rule_lib.net_plane_4_role_rule(request,
                                              cluster_id,
                                              data["role_info"],
                                              data["net_plane_info"])
        api.daisy.cluster_update(
            request,
            cluster_id,
            name=cluster_info["name"],
            networking_parameters=cluster_info["networking_parameters"],
            auto_scale=cluster_info["auto_scale"],
            use_dns=cluster_info["use_dns"],
            description=cluster_info["description"])

        role_list = api.daisy.role_list(request)
        roles = [role for role in role_list
                 if role.cluster_id == cluster_id]
        for role in roles:
            if role.name == "CONTROLLER_HA":
                ha_role_info = data["role_info"]["ha"]
                cluster_role.\
                    set_ha_role_info_for_modify_cluster(request,
                                                        ha_role_info)
            if role.name == "CONTROLLER_LB":
                cluster_role.set_role_info(request,
                                           role.id,
                                           data["role_info"]["lb"])
            if role.name == "COMPUTER":
                cluster_role.\
                    set_computer_role_info(request,
                                           role.id,
                                           data["role_info"]["computer"])
            if role.name == "ZENIC_NFM":
                cluster_role.set_role_info(request,
                                           role.id,
                                           data["role_info"]["zenic_nfm"])
            if role.name == "ZENIC_CTL":
                cluster_role.set_role_info(request,
                                           role.id,
                                           data["role_info"]["zenic_ctl"])

        cluster_net_plane.set_net_plane(request,
                                        cluster_id,
                                        data["net_plane_info"])
    except Exception as e:
        messages.error(request, e)
        exceptions.handle(request, "Cluster modify failed!(%s)" % e)
        LOG.info("modify_submit %s", e)
        response.status_code = 500
        return response

    response.status_code = 200
    return response


@csrf_exempt
def set_cluster_auto_scale(request, cluster_id):
    data = json.loads(request.body)
    response = HttpResponse()
    cluster_info = data["cluster_info"]
    try:
        api.daisy.cluster_update(request,
                                 cluster_id,
                                 name=cluster_info["name"],
                                 auto_scale=cluster_info["auto_scale"])
    except Exception as e:
        messages.error(request, e)
        exceptions.handle(request, "set_cluster_auto_scale failed!(%s)" % e)
        response.status_code = 500
        return response

    response.status_code = 200
    return response

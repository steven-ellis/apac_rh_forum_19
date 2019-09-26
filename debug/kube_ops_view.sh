
#!/bin/bash
#
# This leverages
#  - https://blog.openshift.com/full-cluster-capacity-management-monitoring-openshift/
#  - https://github.com/raffaelespazzoli/kube-ops-view
#  - https://github.com/hjacobs/kube-ops-view
# Documented under
#  - https://kubernetes-operational-view.readthedocs.io/
#

source ./ocp.env
source ./functions

OCP_NAMESPACE=ocp-ops-view

deploy_kubeops ()
{

    oc new-project ${OCP_NAMESPACE}
    oc adm policy add-scc-to-user anyuid -z default -n ocp-ops-view
    oc apply -f https://raw.githubusercontent.com/raffaelespazzoli/kube-ops-view/master/ocp-ops-view.yaml

    oc_wait_for  pod kube-ops-view-stable-kube-ops-view app ${OCP_NAMESPACE}

    oc expose svc kube-ops-view-stable-kube-ops-view

}

cleanup_kubeops ()
{
    oc delete svc kube-ops-view-stable-kube-ops-view

    oc delete -n ${OCP_NAMESPACE} \
       -f https://raw.githubusercontent.com/raffaelespazzoli/kube-ops-view/master/ocp-ops-view.yaml
    

    echo "Deleting the project ${OCP_NAMESPACE}"
    echo "This might take a couple of minutes to return"

    oc delete project ${OCP_NAMESPACE}
}

status_kubeops ()
{
    printInfo "Checking on route for kube-ops-view-stable-kube-ops-view"
    #oc get route -n ${OCP_NAMESPACE} | grep kube-ops-view | awk '{print $2}'
    echo "    http://`oc get route kube-ops-view-stable-kube-ops-view -n ${OCP_NAMESPACE} --template "{{.spec.host}}"`"
}

case "$1" in
  setup)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
	    printWarning "Service Kube Ops View already deployed in ${OCP_NAMESPACE} - Exiting"
        else
            deploy_kubeops
            status_kubeops
        fi
        ;;
  status)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            status_kubeops
        fi
        ;;
  delete|cleanup|remove)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            cleanup_kubeops
        fi
        ;;
  *)
	echo "Usage: $1 {setup|status|delete|cleanup|remove}" >&2
        exit 1
        ;;
esac




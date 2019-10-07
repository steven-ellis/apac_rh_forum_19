#!/bin/bash
#
# Deploy or cleanup a couchbase install

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# We only login as the kubeadmin user if we've got a valid command line

OCP_NAMESPACE=couchbase

setup_couchbase()
{
    printInfo "Create the Couchbase namespace"
    oc new-project couchbase

    printInfo "Populate our secret"
    oc create -f cbauthsecret.yaml -n ${OCP_NAMESPACE}
}

cleanup_couchbase()
{
    printInfo "Clean up our Couchbase environments and remove the Operator"
    printInfo "Don't worry if your see - No resources found"
    printInfo "Remove couchbase subscription"
    #oc delete subscriptions couchbase-enterprise-certified -n ${OCP_NAMESPACE}
    oc delete subscriptions -l csc-owner-name=installed-certified-couchbase -n ${OCP_NAMESPACE}
    oc delete clusterserviceversion couchbase-operator.v1.2.1 -n ${OCP_NAMESPACE}

    printInfo "Make sure we've remove couchbase from our cataloge sources"
    oc delete catalogsourceconfig -n openshift-marketplace installed-certified-couchbase


    printInfo "Remove couchbase operator"
    oc delete deployment -l app=couchbase-operator -n ${OCP_NAMESPACE}
    oc delete replicaset -l app=couchbase-operator -n ${OCP_NAMESPACE}
    printInfo "Remove all apps in the ${OCP_NAMESPACE} namespace"
    oc delete all --all  -n couchbase -n ${OCP_NAMESPACE}

    #oc delete all -l app=couchbase-operator -n ${OCP_NAMESPACE}

    #printInfo "Remove all apps tagged couchbase"
    #oc delete all -l app=couchbase -n ${OCP_NAMESPACE}


    printInfo "Remove our secret"
    oc delete -f cbauthsecret.yaml -n ${OCP_NAMESPACE}

    printInfo "Remove the Couchbase namespace"
    oc delete namespace ${OCP_NAMESPACE}

}


case "$1" in
  setup)
        oc_login
        setup_couchbase
        ;;
  delete|cleanup|remove)
        oc_login
        cleanup_couchbase
        ;;
  *)
        echo "Usage: $N {setup|delete}" >&2
        exit 1
        ;;
esac


#!/bin/bash
#
# Script to scale up/down the number of workers we're operating
#
# Docs
#  - https://docs.openshift.com/container-platform/4.1/machine_management/manually-scaling-machineset.html
#

source ocp.env
source functions

OCP_NAMESPACE=openshift-machine-api
OCP_REGION=${OCP_REGION:-us-east-2}

pre_setup ()
{
    oc_login

    CLUSTERID=$(oc get machineset -n ${OCP_NAMESPACE} -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')

    echo "Existing machinesets"
    oc get machineset -n ${OCP_NAMESPACE}

    #oc scale --replicas=2 machineset <machineset> -n openshift-machine-api

    echo "CLUSTERID = ${CLUSTERID}"
    CLUSTER_A=${CLUSTERID}-worker-${OCP_REGION}a
    CLUSTER_B=${CLUSTERID}-worker-${OCP_REGION}b
    CLUSTER_C=${CLUSTERID}-worker-${OCP_REGION}c
    #cluster-akl-275b-ppsx2-worker-us-east-2a
}

scale_up ()
{
    oc scale --replicas=2 machineset ${CLUSTER_A} -n ${OCP_NAMESPACE}
    oc scale --replicas=2 machineset ${CLUSTER_B} -n ${OCP_NAMESPACE}
    oc scale --replicas=2 machineset ${CLUSTER_C} -n ${OCP_NAMESPACE}

    # We now need to wait for them to all be created
    watch "echo 'wait for our new machines to be READY'; oc get machinesets -n openshift-machine-api"
}

# scale_up_az
#
# $1 = a|b|c = Amazon Availability Zone
#
scale_up_az ()
{
    WORKING_CLUSTER=${CLUSTERID}-worker-${OCP_REGION}${1}
    oc scale --replicas=2 machineset ${WORKING_CLUSTER} -n ${OCP_NAMESPACE}

    # We now need to wait for them to all be created
    watch "echo 'wait for our new machines to be READY in ${OCP_REGION}${1}'; oc get machinesets -n openshift-machine-api"
}

scale_down ()
{
    WORKING_CLUSTER=${CLUSTERID}-worker-${OCP_REGION}${1}
    oc scale --replicas=1 machineset ${CLUSTER_A} -n ${OCP_NAMESPACE}
    oc scale --replicas=1 machineset ${CLUSTER_B} -n ${OCP_NAMESPACE}
    oc scale --replicas=1 machineset ${CLUSTER_C} -n ${OCP_NAMESPACE}

    # We now need to wait for them to all be created
    watch "echo 'wait for our environment to scale down'; oc get machinesets -n openshift-machine-api"
}




case "$1" in
  up)
        pre_setup
        scale_up
        ;;
  down)
        pre_setup
        scale_down
        ;;
  aza)
        pre_setup
        scale_up_az a
        ;;
  azb)
        pre_setup
        scale_up_az b
        ;;
  azc)
        pre_setup
        scale_up_az c
        ;;
  *)
        echo "Usage: $N {up|down|aza|azb|azc}" >&2
        echo " up - scale to 2 replicas for all worker nodes" >&2
        echo " down - scale to 1 replica for all worker nodes" >&2
        echo " aza - scale to 2 replicas for worker nodes in AZ ${OCP_REGION}a" >&2
        echo " azb - scale to 2 replicas for worker nodes in AZ ${OCP_REGION}b" >&2
        echo " azc - scale to 2 replicas for worker nodes in AZ ${OCP_REGION}c" >&2
        exit 1
        ;;
esac


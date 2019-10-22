#!/bin/bash
#
# Script to scale up/down the number of workers we're operating
#
# Docs
#  - https://docs.openshift.com/container-platform/4.1/machine_management/manually-scaling-machineset.html
#

source ./ocp.env
source ./functions

OCP_NAMESPACE=openshift-machine-api
OCP_REGION=${OCP_REGION:-us-east-2}

OUT_DIR=scale_clusters

pre_setup ()
{
    oc_login

    CLUSTERID=$(oc get machineset -n ${OCP_NAMESPACE} -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')

    printInfo "Existing machinesets"
    oc get machineset -n ${OCP_NAMESPACE}

    mkdir -p ${OUT_DIR}

    printInfo "CLUSTERID = ${CLUSTERID}"
    CLUSTER_A=${CLUSTERID}-worker-${OCP_REGION}a
    CLUSTER_B=${CLUSTERID}-worker-${OCP_REGION}b
    CLUSTER_C=${CLUSTERID}-worker-${OCP_REGION}c
}


# worker_config
#
# arg1 = quarkus | java
# clusterid 
#
# Need to 
#  - Rename the cluster ids
#  - insert
#        labels:
#          role: quarkus-node
#          node-role.kubernetes.io/worker: ""
#      providerSpec:
#
worker_config()
{
    type=${1}
    clusterid=${2}
    #newid=${clusterid/-worker-/-${type}worker-\\/}
    newid=${clusterid/-worker-/-${type}worker-}
    printInfo "Creating worker definition for ${type} as ${newid}"
    oc get --export machineset ${clusterid} -o yaml -n openshift-machine-api |\
       sed "s/: worker$/: ${type}worker/" |\
       sed "s/${clusterid}/${newid}/" |\
       sed "/providerSpec:/i\\
        labels: \\
          role: ${type}-node \\
          node-role.kubernetes.io/worker: \"\"" > ${OUT_DIR}/${clusterid}.${type}.yaml

    if [ "${1}" == "ocs" ]; then
        sed -i "s/m4.large/m5a.4xlarge/" ${OUT_DIR}/${clusterid}.${type}.yaml
    fi
}

# create workers
#
# arg1 = quarkus | java
#
# Currently we're only creating two workers
#
create_workers ()
{

    printInfo "Creating two machine definitions for workload ${1}"
    worker_config ${1} ${CLUSTER_A}
    worker_config ${1} ${CLUSTER_B}
    if [ "${1}" == "ocs" ]; then
        worker_config ${1} ${CLUSTER_C}
    fi

}

# start workers
#
start_workers ()
{
    for i in ${CLUSTER_A} ${CLUSTER_B} ${CLUSTER_C}
    do
      for j in quarkus java ocs
      do
        machine_set_file=${OUT_DIR}/${i}.${j}.yaml
        if [ -f ${machine_set_file} ]; then
	     printInfo "Creating new Machine Set from ${i}.${j}.yaml"
             oc create -f ${machine_set_file} -n openshift-machine-api
        fi
      done
    done

    printInfo "We should see some additional machines being provisioned"
    oc get machines -n openshift-machine-api
    sleep 10s
    # We now need to wait for them to all be created
    watch "echo 'wait for our new machines to be READY'; oc get machinesets -n openshift-machine-api"

    printInfo "Wait for the nodes to become active"
    oc_wait_for node quarkus-node role openshift-machine-api
    oc get node -l role=quarkus-node

    oc_wait_for node java-node role openshift-machine-api
    oc get node -l role=java-node

    oc_wait_for node ocs-node role openshift-machine-api
    oc get node -l role=ocs-node
    sleep 5s
}

# stop workers
# 
# $1 = list of workers to stop
#
stop_workers ()
{
    for i in ${CLUSTER_A} ${CLUSTER_B} ${CLUSTER_C}
    do
      for j in $1
      do
        machine_set_file=${OUT_DIR}/${i}.${j}.yaml
        if [ -f ${machine_set_file} ]; then
	     printInfo "Deleting Machine Set from ${i}.${j}.yaml"
             oc delete -f ${machine_set_file} -n openshift-machine-api
        fi
      done
    done

    printInfo "We should see a drop in the number of active machines"
    oc get machines -n openshift-machine-api
    sleep 10s
    oc get machines -n openshift-machine-api
    sleep 2s
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



machineset_status ()
{
    watch "echo 'Look at our current machinesets'; oc get machinesets -n openshift-machine-api"
}


case "$1" in
  up)
        pre_setup
        scale_up
        ;;
  down|baseline)
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
  ocs)
        pre_setup
        create_workers ocs
        ;;
  quarkus)
        pre_setup
        create_workers quarkus
        ;;
  java)
        pre_setup
        create_workers java
        ;;
  start)
        pre_setup
        start_workers
        ;;
  stop)
        pre_setup
        stop_workers "java quarkus"
        ;;
  stop-ocs)
        pre_setup
        stop_workers ocs
        ;;
  status)
        pre_setup
        machineset_status
        ;;
  *)
        echo "Usage: $N {status|quarkus|java|ocs|start|stop}" >&2
        echo " status - Show the current status of our worker nodes" >&2
        echo " quarkus - create machineset for quarkus workload" >&2
        echo " java - create machineset for big fat java workload" >&2
        echo " start - start our workload specific machinesets" >&2
        echo " stop - stop/delete our workload specific machinesets for quarkus/java" >&2
        echo " stop-ocs - stop/delete our workload specific machinesets for ocs" >&2
        echo " Old options - ignore" >&2
        echo "   up - scale to 2 replicas for all worker nodes" >&2
        echo "   down - scale to 1 replica for all worker nodes" >&2
        echo "   aza - scale to 2 replicas for worker nodes in AZ ${OCP_REGION}a" >&2
        echo "   azb - scale to 2 replicas for worker nodes in AZ ${OCP_REGION}b" >&2
        echo "   azc - scale to 2 replicas for worker nodes in AZ ${OCP_REGION}c" >&2
        exit 1
        ;;
esac


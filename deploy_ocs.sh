#!/bin/bash
#
# Script to deploy Rook-Ceph into an OpenShift Workshop Lab
#
# This creates new NVMe based machine sets and uses upstream Rook so 
# that we get CephFS support
#
# Leverage some of the work from
# https://github.com/openshift-metal3/dev-scripts/blob/e40d076cc58e4a4155c26fa03bc6accb93000d8a/10_deploy_rook.sh
#

source ocp.env
source functions

OCP_NAMESPACE=rook-ceph
OCP_REGION=${OCP_REGION:-us-east-2}

#oc_login

# Need a way to make sure pods are running before we continue
#
# $1 = app-name
#
# EG
#    confirm_pods_running rook-ceph-mon
#
confirm_pods_running ()
{

   for i in {1..12}
   do
      printInfo "checking status of pod $1 attempt $i"
      status=` oc get pods -o json --selector=app=${1} -n ${OCP_NAMESPACE} |\
               jq ".items[].status.phase" | uniq`
      if [ ${status} == '"Running"' ] ; then
         return;
      fi
      sleep 10s
   done
   printError "Pod $1 not in Running state" >&2
   exit
}

# Create the storage cluster
create_ceph_storage_cluster ()
{
    oc get machinesets -n openshift-machine-api

    CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
    printInfo $CLUSTERID

    mkdir -p storage_cluster

    cp ./content/support/cluster-workerocs-*.yaml --target-directory=./storage_cluster/
    
    sed -i "s/cluster-28cf-t22gs/$CLUSTERID/g" ./storage_cluster/cluster-workerocs-*.yaml
    sed -i "s/us-east-2/$OCP_REGION/g" ./storage_cluster/cluster-workerocs-*.yaml
    # example if we need to override the AMI
    #sed -i "s/ami-0eef624367320ec26/ami-046fe691f52a953f9/g" ./storage_cluster/cluster-workerocs-*.yaml

    oc create -f ./storage_cluster/cluster-workerocs-us-east-2a.yaml
    oc create -f ./storage_cluster/cluster-workerocs-us-east-2b.yaml
    oc create -f ./storage_cluster/cluster-workerocs-us-east-2c.yaml

    oc get machines -n openshift-machine-api
    sleep 10s

    # See if we've got the storage nodes
    # This is too early as we need the machines to be present
    #oc_wait_for node storage-node role openshift-machine-api
    #sleep 10s

    # We now need to wait for them to all be created
    watch "echo 'wait for our new machines to be READY'; oc get machinesets -n openshift-machine-api"

    # We should be able to use something like this but need to confirm the syntax
    # oc wait --for condition=complete  machines -n openshift-machine-api  -l "machine.openshift.io/cluster-api-machine-type=workerocs" 
    # Confirm we've got the environment
    oc_wait_for node storage-node role openshift-machine-api

    oc get node -l role=storage-node
    sleep 2s
    #watch "echo 'wait for the rest of the nodes to reach Ready'; oc get nodes -l node-role.kubernetes.io/worker"




}



deploy_rook_lab_version ()
{

oc get nodes --show-labels | grep storage-node

oc create -f ./content/support/common.yaml
oc create -f ./content/support/operator-openshift.yaml
oc get pods -n rook-ceph

#confirm_pods_running rook-ceph-operator
oc_wait_for  pod rook-ceph-operator


OPERATOR=$(oc get pod -l app=rook-ceph-operator -n rook-ceph -o jsonpath='{.items[0].metadata.name}')
printInfo $OPERATOR
oc logs $OPERATOR -n rook-ceph | grep "get clusters.ceph.rook.io"

oc create -f ./content/support/cluster.yaml

watch "oc get pods -n rook-ceph | egrep -v -e rook-discover -e rook-ceph-agent"
}


# Use the Upstream where possible
# https://github.com/rook/rook/blob/master/Documentation/ceph-quickstart.md
#
deploy_rook_csi_version ()
{

oc create namespace rook-ceph

oc get nodes --show-labels | grep storage-node

oc create -f ./rook.master/cluster/examples/kubernetes/ceph/common.yaml

# If we are on master this has CSI support
oc create -f ./rook.master/cluster/examples/kubernetes/ceph/operator-openshift.yaml

oc get pods -n rook-ceph

#confirm_pods_running rook-ceph-operator
oc_wait_for  pod rook-ceph-operator

sleep 5s
oc_wait_for  pod rook-discover

OPERATOR=$(oc get pod -l app=rook-ceph-operator -n rook-ceph -o jsonpath='{.items[0].metadata.name}')
printInfo $OPERATOR
oc logs $OPERATOR -n rook-ceph | tail -20

printInfo "Lets pause for  10 seconds"
sleep 10s

printInfo "Create the cluster using the lab definiton but with ceph v14.2.2-20190722"
#oc create -f ./content/support/cluster.yaml
#cat ./content/support/cluster.yaml | sed s/v13.2.5-20190410/v14.2.2-20190722/ > ./storage_cluster/cluster.yaml
#cat ./content/support/cluster.yaml | sed s/v13.2.5-20190410/v14.2.2-20190826/ > ./storage_cluster/cluster.yaml
cat ./content/support/cluster.yaml | sed s/v13.2.5-20190410/v14.2.4-20190917/ > ./storage_cluster/cluster.yaml
oc create -f ./storage_cluster/cluster.yaml

oc_wait_for  pod rook-ceph-agent

oc_wait_for  pod csi-cephfsplugin
oc_wait_for  pod csi-rbdplugin


# Need a more reliable way to run this as we've got a bit
# of a race condition on pod startup
printInfo "We might need 20-60 seconds for the OSDs to activate"
oc_wait_for  pod rook-ceph-mon
sleep 5s
oc_wait_for  pod rook-ceph-mgr
sleep 5s

watch "echo 'wait for the osd pods to be Running'; oc get pods -n rook-ceph | egrep -v -e rook-discover -e rook-ceph-agent"
# We need the watch here has the OSD pods can take quite a while to appear
oc_wait_for  pod rook-ceph-osd

# We now have a seperate function for deploying the toolbox

}



# Reference
# https://github.com/rook/rook/blob/master/Documentation/ceph-block.md
#
enable_rbd ()
{

# Use the CSI RBD Storage Class
oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/csi/rbd/storageclass.yaml



# and make it the default Class
# NOTE we should be able to use our new function default_sc now
oc annotate sc gp2 storageclass.kubernetes.io/is-default-class="false" --overwrite

oc annotate sc rook-ceph-block storageclass.kubernetes.io/is-default-class="true"

oc get sc rook-ceph-block -o yaml

oc get sc

sleep 2
}

# Reference
# https://github.com/rook/rook/blob/master/Documentation/ceph-filesystem.md
#
enable_cephfs ()
{

# Createthe Ceph myfs filesystem
oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/filesystem.yaml

# Check the mds pods have started
#oc -n rook-ceph get pod -l app=rook-ceph-mds

sleep 12s
oc_wait_for  pod rook-ceph-mds
oc -n rook-ceph get pod -l app=rook-ceph-mds
sleep 2s


# Use the CSI CephFS Storage Class
oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml

# Test the storage
oc -n  rook-ceph create -f cephfs_pvc.yaml

}

# Reference
#  - https://github.com/rook/rook/blob/master/Documentation/ceph-examples.md
#  - https://github.com/rook/rook/blob/master/Documentation/ceph-object.md
# And guide from
#  - https://medium.com/@karansingh010/rook-ceph-deployment-on-openshift-4-2b34dfb6a442
#
enable_object ()
{

# Use the CSI Object Storage Class
oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/object-openshift.yaml

printInfo "wait 40 seconds for pod startup"
sleep 40s
oc_wait_for pod rook-ceph-rgw

oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/object-user.yaml

printInfo "Confirming the enties are valid"
oc get CephObjectStore -n rook-ceph
oc get CephObjectStoreUser -n rook-ceph

printInfo "You can confirm the S3 credentials via"
printInfo "oc -n rook-ceph describe secret rook-ceph-object-user-my-store-my-user"

#oc -n rook-ceph get secrets
oc -n rook-ceph describe secret rook-ceph-object-user-my-store-my-user


sleep 2
}

# We need to enable correct monitoring of rook-ceph if we're
# running the upstream rook code based on
#  https://github.com/rook/rook/issues/4636
# and
#  https://github.com/rook/rook/blob/release-1.2/Documentation/ceph-monitoring.md
#
enable_monitoring ()
{
    
    if [ "${OCP_NAMESPACE}" == "rook-ceph" ]; then
        printInfo "Enable monitoring for ${OCP_NAMESPACE}"
        oc label namespace rook-ceph "openshift.io/cluster-monitoring=true"
        oc create -f ./rook.master/cluster/examples/kubernetes/ceph/monitoring/rbac.yaml
        oc create -f ./rook.master/cluster/examples/kubernetes/ceph/monitoring/service-monitor.yaml

        printInfo "Enable the prometheus components into ${OCP_NAMESPACE}"
        oc create -f ./rook.master/cluster/examples/kubernetes/ceph/monitoring/service-monitor.yaml
        oc create -f ./rook.master/cluster/examples/kubernetes/ceph/monitoring/prometheus.yaml
        oc create -f ./rook.master/cluster/examples/kubernetes/ceph/monitoring/prometheus-service.yaml


    else
        printInfo "Monitoring should already be enabled for ${OCP_NAMESPACE}"
    fi   

}

# Deploy the rook-ceph-tools pod if it isn't running
#
# Make sure this works with two namespaces
#  rook-ceph and openshift-storage
#
toolbox ()
{
    # Do we have an existing toolbox deployed
    toolbox=$(oc -n ${OCP_NAMESPACE} get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ "a${toolbox}" == "a" ]; then
        printInfo "Deploy Toolbox into the namespace ${OCP_NAMESPACE}"
        if [ "${OCP_NAMESPACE}" == "rook-ceph" ]; then
            oc create -f ./rook.master/cluster/examples/kubernetes/ceph/toolbox.yaml
        else
            cat ./rook.master/cluster/examples/kubernetes/ceph/toolbox.yaml |\
            sed "s/namespace: rook-ceph/namespace: openshift-storage/" |\
            oc create -f -
        fi
        sleep 5s
        oc_wait_for pod rook-ceph-tools

        export toolbox=$(oc -n ${OCP_NAMESPACE} get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
    else
        printInfo "Using existing toolbox pod ${toolbox} in namespace ${OCP_NAMESPACE}"
        export toolbox

    fi

    printInfo "Now Run"
    echo "ceph status"
    echo "ceph osd status"
    echo "ceph osd tree"
    echo "ceph df"
    echo "rados df"
    echo "exit"
    oc -n ${OCP_NAMESPACE} rsh ${toolbox}
}

# Delete an OCS 4.x environment
delete_ocs_4x ()
{
    printError "$0 not fully implemented yet"

    printInfo "Confirm the OCS Subscription and clean it up"
    oc get subscription  -n openshift-storage

    # Confirm the CSVs
    oc get subscription local-storage-operator-stable-local-storage-manifests-openshift-marketplace \
      -n openshift-storage -o yaml | grep currentCSV
    oc get subscription ocs-subscription -n openshift-storage -o yaml | grep currentCSV


    printInfo "Delete the subscription"
    oc delete subscription local-storage-operator-stable-local-storage-manifests-openshift-marketplace -n openshift-storage
    oc delete subscription ocs-subscription  -n openshift-storage

    printInfo "Delete the CSVs"
    oc delete clusterserviceversion local-storage-operator.v4.2.0 -n openshift-storage
    oc delete clusterserviceversion ocs-operator.v0.0.1 -n openshift-storage


    printInfo "Delete the operator"
    oc delete -f ../ocs-operator/deploy/deploy-with-olm.yaml
    #oc delete -f ../ocs-registry/deploy-with-olm.yaml

    printInfo "See if the project is stuck at terminating"
    for i in 1 2 3 4 5 6 7 8 9 10
    do
        oc get ns|grep -E "openshift-storage|local-storage";
        sleep 1
    done
    #while oc get ns|grep -E "openshift-storage|local-storage"; do sleep 1; done

    printInfo "See if we've got any pods or pvcs "
    oc get pv,pvc -n openshift-storage


    printInfo "Clean up any lingering noobaa services"
    oc delete -n openshift-storage pod/noobaa-core-0 --force --grace-period=0

    printInfo "We may need to clean up Ceph"
    oc patch cephcluster -n openshift-storage $(oc get cephcluster -n openshift-storage \
      -o jsonpath='{ .items[*].metadata.name }') -p '{"metadata":{"finalizers":[]}}' --type=merge

    printInfo "We may need to delete some PVCs or pods"
    oc delete -n openshift-storage pv --all

    printInfo "Force delete remaining pods"
    oc delete pods --all --force --grace-period=0 -n openshift-storage

    printWarning "You may still need to delete your additional worker nodes"
    printWarning "  ./scale_workers.sh stop-ocs"
    printWarning "or untag / taint them manually"


}

# default_sc
#
# Make OCS our default storage class
#

default_sc ()
{

    printInfo "Current storage Classes"
    oc get sc
    if resourceExists sc ocs-storagecluster-ceph-rbd; then
        # take default tag off gp2
        oc annotate sc gp2 storageclass.kubernetes.io/is-default-class="false" --overwrite
        # If we're running downstream
        printInfo "Running downstream with sc ocs-storagecluster-ceph-rbd"
        oc annotate sc ocs-storagecluster-ceph-rbd storageclass.kubernetes.io/is-default-class="true"
    elif resourceExists sc example-storagecluster-ceph-rbd; then
        # take default tag off gp2
        oc annotate sc gp2 storageclass.kubernetes.io/is-default-class="false" --overwrite
        # If we're running upstream
        printInfo "Running upstream with sc example-storagecluster-ceph-rbd"
        oc annotate sc example-storagecluster-ceph-rbd storageclass.kubernetes.io/is-default-class="true"
    elif resourceExists sc rook-ceph-block; then
        # take default tag off gp2
        oc annotate sc gp2 storageclass.kubernetes.io/is-default-class="false" --overwrite
        printInfo "Running Rook with sc rook-ceph-block"
        oc annotate sc rook-ceph-block storageclass.kubernetes.io/is-default-class="true"
    else
        printError "No valid storage class found - making no changes"
    fi
    printInfo "Updated storage class state"
    oc get sc
}

case "$1" in
  all)
        oc_login
        create_ceph_storage_cluster
        deploy_rook_csi_version 
        toolbox
        enable_rbd
        enable_cephfs
        enable_object
        ;;
  base)
        oc_login
        create_ceph_storage_cluster
        deploy_rook_csi_version 
        toolbox
        enable_rbd
        enable_cephfs
        ;;
  storage)
        oc_login
        create_ceph_storage_cluster
        ;;
  rook)
        oc_login
        deploy_rook_csi_version 
        toolbox
        ;;
  rbd)
        oc_login
        enable_rbd
        ;;
  cephfs)
        oc_login
        enable_cephfs
        ;;
  object)
        oc_login
        enable_object
        ;;
  monitoring)
        oc_login
        enable_monitoring
        ;;
  toolbox)
        oc_login
        if projectExists openshift-storage; then
            OCP_NAMESPACE=openshift-storage
            toolbox
        elif projectExists ${OCP_NAMESPACE}; then
            toolbox
        else
            printError "No valid OCS environment - can't deploy toolbox"
        fi
        ;;
  default)
        oc_login
        default_sc
        ;;
  delete)
        oc_login
        if projectExists openshift-storage; then
            OCP_NAMESPACE=openshift-storage
            delete_ocs_4x
        elif projectExists ${OCP_NAMESPACE}; then
            ./cleanup_ocs.sh
        fi
        ;;
  *)
        echo "Usage: $N {all:base:storage:rook:rbd:cephfs:object|delete|monitoring|toolbox}" >&2
        echo " all - perform all storage setup tasks" >&2
        echo " base - excludes object storage setup" >&2
        echo " storage and rook are a pre-requisite for rbd/cephfs/object" >&2
        echo " Delete rook-ceph or OCS 4.x environment" >&2
        echo " monitoring - Enable prometheus monitoring for upstream rook" >&2
        echo " toolbox - Deploys the toolbox pod and executes it" >&2
        echo " default - Makes sure OCS or rook-ceph is the default storag class" >&2
        exit 1
        ;;
esac


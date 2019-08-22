#!/bin/bash
#
# Script to clean up an existing Rook-Ceph environment
#

source ocp.env

OCP_NAMESPACE=rook-ceph

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false



# Create the storage cluster
delete_ceph_storage_cluster ()
{
    oc get machinesets -n openshift-machine-api

    CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
    echo $CLUSTERID

    mkdir -p storage_cluster

    cp ./content/support/cluster-workerocs-*.yaml --target-directory=./storage_cluster/
    
    sed -i "s/cluster-28cf-t22gs/$CLUSTERID/g" ./storage_cluster/cluster-workerocs-*.yaml

    oc delete -f ./storage_cluster/cluster-workerocs-us-east-2a.yaml
    oc delete -f ./storage_cluster/cluster-workerocs-us-east-2b.yaml
    oc delete -f ./storage_cluster/cluster-workerocs-us-east-2c.yaml

    oc get machines -n openshift-machine-api
    sleep 10s

    # We now need to wait for them to all be created
    oc get machinesets -n openshift-machine-api

    # Confirm we've got the environment
    oc get nodes -l node-role.kubernetes.io/worker

    sleep 10s

    # We shouldn't have any
    echo "confirming we have no nodes tagged as storage-node"
    oc get nodes --selector role=storage-node
}



delete_ceph_storage ()
{

    oc -n rook-ceph delete -f ./rook.master/cluster/examples/kubernetes/ceph/csi/rbd/storageclass.yaml
    oc -n rook-ceph delete -f ./rook.master/cluster/examples/kubernetes/ceph/filesystem.yaml
    oc -n rook-ceph delete -f ./rook.master/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml
    oc -n rook-ceph delete -f cephfs_pvc.yaml

    # Delete any provisioned storage
    oc delete pvc --all
    oc delete pv --all

}

delete_operator ()
{

    oc delete -f ./content/support/cluster.yaml
    oc delete -f ./content/support/operator-openshift.yaml
    oc delete -f ./content/support/common.yaml
}

delete_ceph_storage

delete_operator

delete_ceph_storage_cluster 

# Delete the project
oc delete project ${OCP_NAMESPACE}

#!/bin/bash
#
# Script to deploy Rook-Ceph into an OpenShift Workshop Lab
#
# This creates new NVMe based machine sets and uses upstream Rook so 
# that we get CephFS support
#

source ocp.env

OCP_NAMESPACE=rook-ceph

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

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
      echo "checking status of pod $1 attempt $i"
      status=` oc get pods -o json --selector=app=${1} -n ${OCP_NAMESPACE} |\
               jq ".items[].status.phase" | uniq`
      if [ ${status} == '"Running"' ] ; then
         return;
      fi
      sleep 10s
   done
   echo "Pod $1 not in Running state" >&2
   exit
}


# Create the storage cluster
create_ceph_storage_cluster ()
{
    oc get machinesets -n openshift-machine-api

    CLUSTERID=$(oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}')
    echo $CLUSTERID

    mkdir -p storage_cluster

    cp ./content/support/cluster-workerocs-*.yaml --target-directory=./storage_cluster/
    
    sed -i "s/cluster-28cf-t22gs/$CLUSTERID/g" ./storage_cluster/cluster-workerocs-*.yaml

    oc create -f ./storage_cluster/cluster-workerocs-us-east-2a.yaml
    oc create -f ./storage_cluster/cluster-workerocs-us-east-2b.yaml
    oc create -f ./storage_cluster/cluster-workerocs-us-east-2c.yaml

    oc get machines -n openshift-machine-api
    sleep 10s

    # We now need to wait for them to all be created
    watch oc get machinesets -n openshift-machine-api

    # Confirm we've got the environment
    watch oc get nodes -l node-role.kubernetes.io/worker
}

#create_ceph_storage_cluster


deploy_rook_lab_version ()
{

oc get nodes --show-labels | grep storage-node

oc create -f ./content/support/common.yaml
oc create -f ./content/support/operator-openshift.yaml
watch oc get pods -n rook-ceph
OPERATOR=$(oc get pod -l app=rook-ceph-operator -n rook-ceph -o jsonpath='{.items[0].metadata.name}')
echo $OPERATOR
oc logs $OPERATOR -n rook-ceph | grep "get clusters.ceph.rook.io"

oc create -f ./content/support/cluster.yaml

watch "oc get pods -n rook-ceph | egrep -v -e rook-discover -e rook-ceph-agent"

# Deploy Toolbox
oc create -f ./content/support/toolbox.yaml

export toolbox=$(oc -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
oc -n rook-ceph rsh $toolbox
ceph status
ceph osd status
ceph osd tree
ceph df
rados df
exit
}



# Use the Upstream where possible
deploy_rook_csi_version ()
{

oc create namespace rook-ceph

oc get nodes --show-labels | grep storage-node

oc create -f ./rook/cluster/examples/kubernetes/ceph/common.yaml

# If we are on master this has CSI support
oc create -f ./rook/cluster/examples/kubernetes/ceph/operator-openshift.yaml
watch oc get pods -n rook-ceph

OPERATOR=$(oc get pod -l app=rook-ceph-operator -n rook-ceph -o jsonpath='{.items[0].metadata.name}')
echo $OPERATOR
oc logs $OPERATOR -n rook-ceph | grep "get clusters.ceph.rook.io"

echo "Lets pause for a 10 seconds"
sleep 10s

echo "Create the cluster using the lab definiton but with ceph v14.2.2-20190722"
#oc create -f ./content/support/cluster.yaml
cat ./content/support/cluster.yaml | sed s/v13.2.5-20190410/v14.2.2-20190722/ > cluster.yaml
oc create -f ./cluster.yaml

watch "oc get pods -n rook-ceph | egrep -v -e rook-discover -e rook-ceph-agent"

#
echo "We might need 20-60 seconds for the OSDs to activate"

# Deploy Toolbox
oc create -f ./content/support/toolbox.yaml

export toolbox=$(oc -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')
echo "Now Run"
echo "ceph status"
echo "ceph osd status"
echo "ceph osd tree"
echo "ceph df"
echo "rados df"
echo "exit"
oc -n rook-ceph rsh $toolbox
}


 deploy_rook_csi_version 

enable_rbd ()
{

# Use the CSI RBD Storage Class
oc -n rook-ceph create -f ./rook/cluster/examples/kubernetes/ceph/csi/rbd/storageclass.yaml



# and make it the default Class
oc annotate sc gp2 storageclass.kubernetes.io/is-default-class="false" --overwrite

oc annotate sc rook-ceph-block storageclass.kubernetes.io/is-default-class="true"

oc get sc rook-ceph-block -o yaml

oc get sc

sleep 2
}

enable_cephfs ()
{

# Createthe Ceph myfs filesystem
oc -n rook-ceph create -f ./rook/cluster/examples/kubernetes/ceph/filesystem.yaml

# Check the mds pods have started
oc -n rook-ceph get pod -l app=rook-ceph-mds

sleep 10s
oc -n rook-ceph get pod -l app=rook-ceph-mds
sleep 2s


# Use the CSI CephFS Storage Class
oc -n rook-ceph create -f ./rook/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml

# Test the storage
oc -n  rook-ceph create -f cephfs_pvc.yaml

}




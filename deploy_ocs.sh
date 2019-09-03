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
echo $OPERATOR
oc logs $OPERATOR -n rook-ceph | tail -20

echo "Lets pause for  10 seconds"
sleep 10s

echo "Create the cluster using the lab definiton but with ceph v14.2.2-20190722"
#oc create -f ./content/support/cluster.yaml
#cat ./content/support/cluster.yaml | sed s/v13.2.5-20190410/v14.2.2-20190722/ > ./storage_cluster/cluster.yaml
cat ./content/support/cluster.yaml | sed s/v13.2.5-20190410/v14.2.2-20190826/ > ./storage_cluster/cluster.yaml
oc create -f ./storage_cluster/cluster.yaml

oc_wait_for  pod rook-ceph-agent

oc_wait_for  pod csi-cephfsplugin
oc_wait_for  pod csi-rbdplugin


# Need a more reliable way to run this as we've got a bit
# of a race condition on pod startup
echo "We might need 20-60 seconds for the OSDs to activate"
oc_wait_for  pod rook-ceph-mon
sleep 5s
oc_wait_for  pod rook-ceph-mgr
sleep 5s

watch "echo 'wait for the osd pods to be Running'; oc get pods -n rook-ceph | egrep -v -e rook-discover -e rook-ceph-agent"
# We need the watch here has the OSD pods can take quite a while to appear
oc_wait_for  pod rook-ceph-osd

#

# Deploy Toolbox
oc create -f ./rook.master/cluster/examples/kubernetes/ceph/toolbox.yaml
sleep 2s
oc_wait_for  pod rook-ceph-tools

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



# Reference
# https://github.com/rook/rook/blob/master/Documentation/ceph-block.md
#
enable_rbd ()
{

# Use the CSI RBD Storage Class
oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/csi/rbd/storageclass.yaml



# and make it the default Class
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

echo "wait 40 seconds for pod startup"
sleep 40s
oc_wait_for pod rook-ceph-rgw

oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/object-user.yaml

echo "Confirming the enties are valid"
oc get CephObjectStore -n rook-ceph
oc get CephObjectStoreUser -n rook-ceph

echo "You can confirm the S3 credentials via"
echo "oc -n rook-ceph describe secret rook-ceph-object-user-my-store-my-user"

#oc -n rook-ceph get secrets
oc -n rook-ceph describe secret rook-ceph-object-user-my-store-my-user


sleep 2
}

case "$1" in
  all)
        create_ceph_storage_cluster
        deploy_rook_csi_version 
        enable_rbd
        enable_cephfs
        enable_object
        ;;
  base)
        create_ceph_storage_cluster
        deploy_rook_csi_version 
        enable_rbd
        enable_cephfs
        ;;
  storage)
        create_ceph_storage_cluster
        ;;
  rook)
        deploy_rook_csi_version 
        ;;
  rbd)
        enable_rbd
        ;;
  cephfs)
        enable_cephfs
        ;;
  object)
        enable_object
        ;;
  *)
        echo "Usage: $N {all:base:storage:rook:rbd:cephfs:object}" >&2
        echo " all - perform all storage setup tasks" >&2
        echo " base - excludes object storage setup" >&2
        echo " storage and rook are a pre-requisite for rbd/cephfs/object" >&2
        exit 1
        ;;
esac


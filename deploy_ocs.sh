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

# Wait for a pod/node to become running
#
# $1 = [pod|node]
# $2 = app-name
#
# EG
#    oc_wait_for pod rook-ceph-mon
#
oc_wait_for ()
{
    echo "Waiting for the ${1}s tagged ${2} = ready"
    oc wait --for condition=ready  ${1}-l app=${2} -n ${OCP_NAMESPACE} --timeout=1200s
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
    watch "echo 'wait for our new machines to be READY'; oc get machinesets -n openshift-machine-api"

    # We should be able to use something like this but need to confirm the syntax
    # oc wait --for condition=complete  machines -n openshift-machine-api  -l "machine.openshift.io/cluster-api-machine-type=workerocs" 

    # Confirm we've got the environment
    echo "Waiting for the nodes tagged storage-node = ready"
    oc wait --for condition=ready  node -l role=storage-node  --timeout=1200s
    oc get node -l role=storage-node
    watch "echo 'wait for the rest of the nodes to reach Ready'; oc get nodes -l node-role.kubernetes.io/worker"




}



deploy_rook_lab_version ()
{

oc get nodes --show-labels | grep storage-node

oc create -f ./content/support/common.yaml
oc create -f ./content/support/operator-openshift.yaml
oc get pods -n rook-ceph

confirm_pods_running rook-ceph-operator


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
echo "Waiting for rook-ceph-operator = Ready"
oc wait --for condition=ready  pod -l app=rook-ceph-operator -n ${OCP_NAMESPACE} --timeout=1200s

sleep 5s
echo "Waiting for rook-ceph-discover = Ready"
oc wait --for condition=ready  pod -l app=rook-discover -n ${OCP_NAMESPACE} --timeout=1200s

OPERATOR=$(oc get pod -l app=rook-ceph-operator -n rook-ceph -o jsonpath='{.items[0].metadata.name}')
echo $OPERATOR
oc logs $OPERATOR -n rook-ceph | tail -20

echo "Lets pause for  10 seconds"
sleep 10s

echo "Create the cluster using the lab definiton but with ceph v14.2.2-20190722"
#oc create -f ./content/support/cluster.yaml
cat ./content/support/cluster.yaml | sed s/v13.2.5-20190410/v14.2.2-20190722/ > ./storage_cluster/cluster.yaml
oc create -f ./storage_cluster/cluster.yaml

echo "Waiting for rook-ceph-agent = Ready"
oc wait --for condition=ready  pod -l app=rook-ceph-agent -n ${OCP_NAMESPACE} --timeout=1200s

echo "Waiting for csi-cephfsplugin = Ready"
oc wait --for condition=ready  pod -l app=csi-cephfsplugin -n ${OCP_NAMESPACE} --timeout=1200s
echo "Waiting for csi-rbdplugin = Ready"
oc wait --for condition=ready  pod -l app=csi-rbdplugin -n ${OCP_NAMESPACE} --timeout=1200s


echo "Waiting for rook-ceph-mon = Ready"
oc wait --for condition=ready  pod -l app=rook-ceph-mon -n ${OCP_NAMESPACE} --timeout=1200s
echo "Waiting for rook-ceph-osd = Ready"
oc wait --for condition=ready  pod -l app=rook-ceph-osd -n ${OCP_NAMESPACE} --timeout=1200s
sleep 10s
watch "echo 'wait for the osd pods to be Running'; oc get pods -n rook-ceph | egrep -v -e rook-discover -e rook-ceph-agent"

#
echo "We might need 20-60 seconds for the OSDs to activate"

# Deploy Toolbox
oc create -f ./rook.master/cluster/examples/kubernetes/ceph/toolbox.yaml
sleep 2s
echo "Waiting for rook-ceph-tools = Ready"
oc wait --for condition=ready  pod -l app=rook-ceph-tools -n ${OCP_NAMESPACE} --timeout=1200s

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
oc -n rook-ceph get pod -l app=rook-ceph-mds

sleep 10s
oc -n rook-ceph get pod -l app=rook-ceph-mds
sleep 2s


# Use the CSI CephFS Storage Class
oc -n rook-ceph create -f ./rook.master/cluster/examples/kubernetes/ceph/csi/cephfs/storageclass.yaml

# Test the storage
oc -n  rook-ceph create -f cephfs_pvc.yaml

}

create_ceph_storage_cluster

# Only use one of the rook deploy calls
#deploy_rook_lab_version
deploy_rook_csi_version 

enable_rbd
enable_cephfs


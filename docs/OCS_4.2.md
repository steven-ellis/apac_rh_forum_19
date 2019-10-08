# OpenShift Container Storage 4.2

Need to test/validate [OpenShift 4.2](./OpenShift_4.2.md) in
addition to OCS 4.x. Use the [OpenShift 4.2](./OpenShift_4.2.md)
for status tracking, and this document with cover the install steps for
OCS 4.2

Baseline installation of installer OpenShift on AWS is covered under
[OpenShift Installer](OpenShiftInstaller.md).


## Key Refs

- [Upstream Operator](https://github.com/openshift/ocs-operator)
    - Currently working with branch release-4.2
- Downstream Operator
    - Currently requires Red Hat VPN access ahead of GA

# OCS Installation

## Pre Work - Deploy OCP 4.2 on AWS / VMWare

Use [OpenShift Installer](OpenShiftInstaller.md) for AWS Install

## Scale additional Storage Worker Nodes
We can use the scale_workers.sh script from our APAC RH Forum Demo to scale
up 3 additional storage specific worker nodes. We currently recommend 
**m5.4xlarge** but for our demo we're running **m5a.2xlarge**.

Update ocp.env to include our environment created via the
[OpenShift Installer](OpenShiftInstaller.md)
```
./setup.sh
./scale_workers.sh ocs
./scale_workers.sh start
```

## OCS 4.2 Alpha Deployment Steps

### Potentially redundant step
This is now performed by the operator and my no longer be required
```
# Pre requisite - label the nodes were using for storage - only for upstream
oc label nodes <NodeName> cluster.ocs.openshift.io/openshift-storage=''

 
# Optional taint the nodes to avoid other workloads being scheduled  - only for upstream
oc adm taint nodes <NodeNames> node.ocs.openshift.io/storage=true:NoSchedule
```


### Deploy OCS Meta Operator
```
# For the upstream Operator - release-4.2
#oc create -f ../ocs-operator/deploy/deploy-with-olm.yaml

# or the downstream build - branch ocs-4.2-rhel-8
# only until we're in Operator Hub
oc create -f ../ocs-registry/deploy-with-olm.yaml

# Keep an eye on the operators starting
watch -n 5 oc get pods -n openshift-storage 

# wait for operator to be active - may take 5-6 minutes
oc get csv -n openshift-storage

# Create our base storage cluster
# We can create via a CRD or create via the OpenShift Console
# Using Upstream
# oc create -f ../ocs-operator/deploy/crds/ocs_v1_storagecluster_cr.yaml
# or the downstream 
# oc create -f ../ocs-registry/ocs_v1_storagecluster_cr.yaml

# Keep an eye on the pods being created
# In particular the Ceph OSDs becoming Ready
watch -n 5 oc get pods -n openshift-storage 
```

### Make Ceph-RBD default storage class

```
# Confirm our storage classes
oc get sc

# take default tag off gp2
oc annotate sc gp2 storageclass.kubernetes.io/is-default-class="false" --overwrite

# If we're running upstream
oc annotate sc example-storagecluster-ceph-rbd storageclass.kubernetes.io/is-default-class="true"

# If we're running downstream
oc annotate sc ocs-storagecluster-ceph-rbd storageclass.kubernetes.io/is-default-class="true"
```


## Deployment issues

- Won't deploy with **m5.2xlarge** instances
- Default OCS 4.2 environment uses m4.large (2CPU / 8GB RAM) workers which aren't large enough for NooBaa to deploy
    - NooBaa requires 4 CPU / 8GB RAM
    - Still stuck in CrashLoopBackOff

### Additional Compute resource for NooBaa

You need to scale the machine count for one of the OCS Machine Sets so we have additional compute capacity to run NooBaa

### Deploying the ceph toolbox for debugging
Default deployment of OCS 4.x doesn't include the Ceph-toolbox pod which can be used for debugging.
In order to use the deployment from upstream rook we need to rename the namespace

```
cat rook.master/cluster/examples/kubernetes/ceph/toolbox.yaml |\
sed "s/namespace: rook-ceph/namespace: openshift-storage/" |\
oc create -f -
```

We can then access the toolbox via
```
export toolbox=$(oc -n openshift-storage get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}')

oc -n openshift-storage rsh $toolbox
```
Typical Ceph debugging commands are
```
ceph status
ceph osd status
ceph osd tree
ceph df
rados df
```

### Test the CephFS Storage
We can create a simple example PV to validate CephFS is working correctly
```
# Confirm our storage classes
oc get sc

# If we're running upstream
cat cephfs_pvc.yaml |\
sed "s/storageClassName: csi-cephfs/storageClassName: example-storagecluster-cephfs/" |\
oc create -n openshift-storage -f -


# If we're running downstream
cat cephfs_pvc.yaml |\
sed "s/storageClassName: csi-cephfs/storageClassName: ocs-storagecluster-cephfs/" |\
oc create -n openshift-storage -f -


# Lets see what storage claim's we got
oc get pv,pvc -n openshift-storage
```

## Removing the instace
A large part of this has now been scripted as part of [deploy_ocs.sh](../deploy_ocs.sh).
Currently we don't remove the enviroment labels/taints or delete the additional worker nodes via the delete script.
This can be invoked via
```
./deploy_ocs.sh delete
```

### Manual OCS 4.x removal
First delete the subscriptions
```
oc get subscription  -n openshift-storage

# Confirm the CSVs
oc get subscription local-storage-operator-stable-local-storage-manifests-openshift-marketplace -n openshift-storage -o yaml | grep currentCSV
oc get subscription ocs-subscription -n openshift-storage -o yaml | grep currentCSV


# Delete the subscription
oc delete subscription local-storage-operator-stable-local-storage-manifests-openshift-marketplace -n openshift-storage
oc delete subscription ocs-subscription  -n openshift-storage

# Delete the CSVs
oc delete clusterserviceversion local-storage-operator.v4.2.0 -n openshift-storage
oc delete clusterserviceversion ocs-operator.v0.0.1 -n openshift-storage


# Delete the operator
#oc delete -f ../ocs-operator/deploy/deploy-with-olm.yaml
oc delete -f ../ocs-registry/deploy-with-olm.yaml

# See if the project is stuck at terminating
while oc get ns|grep -E "openshift-storage|local-storage"; do sleep 1; done

# See if we've got any pods or pvcs 
oc get pvs -n openshift-storage

# We may need to delete some PVCs or pods
oc delete -n openshift-storage pv <PV>

oc delete -n openshift-storage pod/noobaa-core-0 --force --grace-period=0

# We may need to clean up Ceph
oc patch cephcluster $(oc get cephcluster -n openshift-storage -o jsonpath='{ .items[*].metadata.name }') -p '{"metadata":{"finalizers":[]}}' --type=merge

# Force delete remaining pods
oc delete pods --all --force --grace-period=0 -n openshift-storage

# We need to make sure the machines are unlabeled 
for i in $(oc get nodes -l cluster.ocs.openshift.io/openshift-storage= -o 'jsonpath={ .items[*].metadata.name  }' -n openshift-storage )
do
oc patch node $i -p '{"spec":{"taints":[]}}' --type=merge
done

for i in $(oc get nodes -l cluster.ocs.openshift.io/openshift-storage= -o 'jsonpath={ .items[*].metadata.name }' -n openshift-storage )
do
oc label node  $i cluster.ocs.openshift.io/openshift-storage-
done
```

Also reference uninstall notes under

- https://access.redhat.com/documentation/en-us/red_hat_openshift_container_storage/4.2/html-single/deploying_openshift_container_storage/index#procedure_uninstalling-ocs_en-usrhocs


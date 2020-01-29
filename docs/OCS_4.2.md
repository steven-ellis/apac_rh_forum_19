# OpenShift Container Storage 4.2

Need to test/validate [OpenShift 4.2](./OpenShift_4.2.md) in
addition to OCS 4.x. Use the [OpenShift 4.2](./OpenShift_4.2.md)
for status tracking, and this document with cover the install steps for
OCS 4.2

Baseline installation of installer OpenShift on AWS is covered under
[OpenShift Installer](OpenShiftInstaller.md).

If you have access to the updated OCS 4.2 RHPDS hosted workshop make
sure that your **ocp.env** has the correct values for
```
OCP_USER=
OCP_PASS=
OCP_REGION=
```

## Key Refs

- [Upstream Operator](https://github.com/openshift/ocs-operator)
    - Currently working with branch release-4.2
- Downstream Operator
    - Currently requires Red Hat VPN access ahead of GA

# OCS Installation

## Pre Work - Deploy OCP 4.2 on AWS / VMWare / RHPDS

Follow [OpenShift Installer](OpenShiftInstaller.md) for AWS Install.

For RHPDS select the "OpenShift 4.2 Workshop"

## Confirm we have 3 Worker Nodes
Default AWS deployment has 3 worker nodes, but default RHPDs deployment might
have a smaller number of worker nodes
```
oc get machinesets -n openshift-machine-api
```
If you only have workers in 2 AZs you need to correct this before performing subsequent steps
```
./scale_workers.sh baseline
```

## Make sure you have the correct region
When you check the machinesets above you will see details of the AWS region
your environment is using. The default regions tend to be us-east-1 and us-east-2.
Make sure you've updated your **ocp.env**
```
OCP_REGION=<region-value>
```



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

## OCS 4.2 GA Deployment
The operator is now in Operator Hub and can be installed directly
from the OpenShift web console. Install this into the openshift-storage
project/namespace.

We recommend you confirm that the version of OCP aligns with the OCS Operator
via the following compatibilty matrix, or the deployment might have issues.

* https://access.redhat.com/articles/4731161

You can confirm the names of the workers you should use for the OCS deployment via
```
oc get nodes --show-labels | grep ocs
```

In addition make sure you have followed the **Before Subscription** steps
in the operator install notes

While the cluster is being build you can watch the associated pods via
```
watch -n 5 oc get pods -n openshift-storage
```

See below if you want to make OCS the default block storage class

## OCS 4.2 Automated Operator deployment

Most of this process has now been automated and rolled into the standard 
deployment script. Simply execute
```
deploy_ocs.sh base
deploy_ocs.sh operator
```
or
```
deploy_ocs.sh all
```

Once the Operator is installed you can enable a Storage Cluster via
the Operator in the openshift-storage namespace following the instuctions
for the GA Operator.

## OCS 4.x Upstream manual operator deployment

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
```

We have an option of creating the Storage Cluster via the OpenShift OCS
Operator console or via a custom resource definition

For a CR based approach follow
```
# Create our base storage cluster
# We can create via a CRD or create via the OpenShift Console
# Using Upstream
# oc create -f ../ocs-operator/deploy/crds/ocs_v1_storagecluster_cr.yaml
# or the downstream 
# oc create -f ../ocs-registry/ocs_v1_storagecluster_cr.yaml
```

If your using the operator console first confirm the names of the tagges OCS
worker nodes
```
oc get nodes --show-labels | grep ocs
```


Keep an eye on the pods being created - in particular the Ceph OSDs becoming Ready.
In addition the noobaa-core container won't become active until the storage is working correctly.
```
watch -n 5 oc get pods -n openshift-storage 
```

## Make Ceph-RBD default storage class

```
./deploy_ocs default
```


## Deployment issues

- Won't deploy with **m5.2xlarge** instances
- Default OCS 4.2 environment uses m4.large (2CPU / 8GB RAM) workers which aren't large enough for NooBaa to deploy
    - NooBaa requires 4 CPU / 8GB RAM
    - Still stuck in CrashLoopBackOff

### New RHPDS OCP 4.2 Workshop only has 2 worker nodes

Documented work around for this issue above

### Additional Compute resource for NooBaa - **No longer an Issue**

We originally needed to scale the machine count for one of the OCS Machine Sets so we have additional compute capacity to run NooBaa. It appears we can now deploy it with a default set of worker nodes

### Deploying the ceph toolbox for debugging
Default deployment of OCS 4.x doesn't include the Ceph-toolbox pod which can be used for debugging.

The [deploy_ocs.sh](../deploy_ocs.sh) script has been updated to enable and run the toolbox via
```
./deploy_ocs.sh toolbox
```

If you want to deploy it manually you can use the the deployment from upstream rook, but we need to rename the namespace in the yaml.

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

## Removing the OCS Deployment
A large part of this has now been scripted as part of [deploy_ocs.sh](../deploy_ocs.sh).
Currently we don't remove the enviroment labels/taints or delete the additional worker nodes via the delete script.
This can be invoked via
```
./deploy_ocs.sh delete
```

You can then delete the additional worker nodes via
```
./scale_workers.sh stop-ocs
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


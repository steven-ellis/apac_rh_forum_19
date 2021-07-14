# Demo / Environment Troubleshooting
Some tips / trips for troubleshooting potential issues

* [Quarkus workloads won't scale to 50](#quarkus-workloads-wont-scale)
* [Node Evacuation](#evacuating-a-node-before-removing) before deletion
* [Stuck on oc wait](#stuck-on-a-an-oc-wait)
* [Operators Missing from Operator Hub](#operators-missing-from-operator-hub)
* [Stuck namespaces that are always 'Terminating'](#stock-namespaces-that-are-always-'terminating')

Also refernce our guide on [Debugging](./Debugging.md)

=======

## Quarkus workloads won't scale
This is usually because there are other workloads scheduled on the compute workers/nodes

```
# Make sure we are logged in and in the correct project
./setup.sh

oc project supersonic-subatomic-java

for n in `oc get nodes -l role=java-node --no-headers | cut -d " " -f1`
do
    oc get pods --all-namespaces  --no-headers --field-selector spec.nodeName=${n} 
done

for n in `oc get nodes -l role=quarkus-node --no-headers | cut -d " " -f1`
do
    oc get pods --all-namespaces  --no-headers --field-selector spec.nodeName=${n} 
done
```

To identify the number of errant workloads
```
for n in `oc get nodes -l role=java-node --no-headers | cut -d " " -f1`
do
    oc get pods --all-namespaces  --no-headers --field-selector spec.nodeName=${n} 
done | egrep -v supersonic-subatomic-java | wc -l


for n in `oc get nodes -l role=quarkus-node --no-headers | cut -d " " -f1`
do
    kubectl get pods --all-namespaces  --no-headers --field-selector spec.nodeName=${n} 
done | egrep -v supersonic-subatomic-java | wc -l
```

This can usually be resolved by making sure you have correct taints/tollerances

https://docs.openshift.com/container-platform/4.1/nodes/scheduling/nodes-scheduler-taints-tolerations.html

We have updated [quarkus.sh](../quarkus.sh) to allow setting of taints - Reference [Quarkus.md](./Quarkus.md)

## Evacuating a node before removing

COMPLETE

## Stuck on a an "oc wait"

Sometimes an a wait can take a long time to timeout. One way to overcome this is
```
ps -eaf  | grep "oc wait"

kill <pid>
```

## Operators Missing from Operator Hub

This can happen if one of the catalogue sources isn't working correcly. Some additional
tips have been documened under [Operator Marketplace Debugging](https://github.com/operator-framework/operator-marketplace/blob/master/docs/troubleshooting.md)

Potential BZ - https://bugzilla.redhat.com/show_bug.cgi?id=1700100

All pods should be in a running state
```
oc get pods -n openshift-marketplace
```
If any of the pods aren't in the correct state inspect via
```
oc logs <name of pod>
```
We currently havd an outstanding issue with the **certified-operators** container and 
OpenShift 4.1.3 which can be resolved via [operator_fix.sh](../operator_fix.sh)


### Analysis of Operator Hub Issue
Reference - https://blog.openshift.com/openshift-4-install-experience/

This may releate to Cluster Version Operator (CVO) replacing the modified container image

Look at the environment
```
oc describe clusterversion


# Use the release info to dig deeper - for 4.1.3 it should be
#  quay.io/openshift-release-dev/ocp-release@sha256:f852f9d8c2e81a633e874e57a7d9bdd52588002a9b32fc037dba12b67cf1f8b0

oc adm release info  quay.io/openshift-release-dev/ocp-release@sha256:f852f9d8c2e81a633e874e57a7d9bdd52588002a9b32fc037dba12b67cf1f8b0
```

We now have the sha256 sums for all of the components we're supposed to be running. I suspect that this issue resides with operator-marketplace
```
oc adm release info  quay.io/openshift-release-dev/ocp-release@sha256:f852f9d8c2e81a633e874e57a7d9bdd52588002a9b32fc037dba12b67cf1f8b0 | grep operator-marketplace
  operator-marketplace                          sha256:52d81af840ea9e77347c31593bd65f6cc6171e7b35cf8fd620e8a16238d96330
```


Critical error we're seeing after a re-depoyment is **Liveness probe errored**. Taking a look at the pods
```
oc describe pod certified-operators -n openshift-marketplace

# Critical part is
    Liveness:       exec [grpc_health_probe -addr=localhost:50051] delay=5s timeout=1s period=10s #success=1 #failure=30
    Readiness:      exec [grpc_health_probe -addr=localhost:50051] delay=5s timeout=1s period=10s #success=1 #failure=30
 
```


## Stuck namespaces that are always 'Terminating'
This is based on a [note](https://github.com/rht-labs/enablement-codereadyworkspaces/blob/master/HELP.md) from the codeready workspaces lab

Sometimes CRW doesn't release resources correctly when cleaning up and you need to force a cleanup

```
# First confirm we've got some namespaces/projects stuck at Terminating
oc get ns | grep Terminating 


# Then setup our environment do we have the correct OCP API Endpoint
OCP_ENDPOINT=`oc whoami --show-server`

# Cleanup the stuck namespaces
for i in $( oc get ns | grep Terminating | awk '{print $1}'); do echo $i; oc get ns $i -o json| jq "del(.spec.finalizers[0])"> "$i.json"; curl -k -H "Authorization: Bearer $(oc whoami -t)" -H "Content-Type: application/json" -X PUT --data-binary @"$i.json" "${OCP_ENDPOINT}/api/v1/namespaces/$i/finalize"; done
for i in $(oc get pvc | grep Terminating| awk '{print $1}'); do oc patch pvc $i --type='json' -p='[{"op": "replace", "path": "/metadata/finalizers", "value":[]}]'; done
for i in $(oc get pv | grep Released| awk '{print $1}'); do oc patch pv $i --type='json' -p='[{"op": "replace", "path": "/metadata/finalizers", "value":[]}]'; done
```


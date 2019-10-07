# Demo / Environment Troubleshooting
Some tips / trips for troubleshooting potential issues

* [Quarkus workloads won't scale to 50](#quarkus-workloads-wont-scale)
* [Node Evacuation](#evacuating-a-node-before-removing) before deletion
* [Stuck on oc wait](#stuck-on-a-an-oc-wait)
* [Operators Missing from Operator Hub](#operators-missing-from-operator-hub)

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

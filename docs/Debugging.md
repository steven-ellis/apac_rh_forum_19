# Debugging OpenShift
Some tips / trips for debugging issues with OpenShift

Also refernce our guide on [Troubleshooting](./Troubleshooting.md)

=======

## oc adm top
This can help at a high level identify top pods and nodes
```
oc adm top nodes

oc adm top pods -n <namespace>
```

For Example
```
# Look at Rook-Ceph
oc adm top pods -n rook-ceph

# Look at 3scale 2.5
oc adm top pods -n 3scale25-mt-api0
```

You can then dig a bit deeper into a specific node via
```
oc describe node <node-name>
```

## Where are my pods running
One issue is to know where all of the workloads for a given project are running
```
get pod -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName 

# or
get pod -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName  -n namespace
```

## Deploy Kube Ops View

Documented under

- https://kubernetes-operational-view.readthedocs.io/

References

- https://blog.openshift.com/full-cluster-capacity-management-monitoring-openshift/
- https://github.com/raffaelespazzoli/kube-ops-view
- https://github.com/hjacobs/kube-ops-view

Install - will provide a route you can browse to
```
./debug/kube_ops_view.sh setup

# Double check the route
./debug/kube_ops_view.sh status

# cleanup
./debug/kube_ops_view.sh cleanup
```

## Deploy Kubernetes Dashboard

References

- https://github.com/kubernetes/dashboard

Install
```
# Make sure we're logged into the OpenShift Cluster
./setup.sh

oc apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

oc proxy
```

You can then access the dashboard via

- http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

For Authentication select **Token** based, then to get the API Token browse to your OpenShift Console and selecct

- User Name 
- Copy Login Command
- Display token
- copy the API token

Using the Kubernetes Dashboard

- A good starting point is **Overview** with all namespaces selected.
- The node level view is also great a visualising node health

## Namespace / Project stuck at terminating

- https://github.com/VeerMuchandi/ocp4-extras/tree/master/cleanupHangingObjects#cleaning-up-projects-hanging-in-terminating-state

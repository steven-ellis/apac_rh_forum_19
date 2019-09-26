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

# APAC Red Hat Forum OpenShift Demos
Demo deployment scripts for Red Hat APAC Forum 2019

The Demo covers a broad range of Red Hat technologies running on 
Red Hat OpenShift Container Platform 4.x

* 3Scale
* Istio Service Mesh
* Kubernetes Operators
* Codeready Workspaces

Currently the deployment needs to be staged due to pod/container dependencies.

The scripts make use of “watch” to keep an eye on the environment and you’ll have to occasionally press CTRL-C to continue.

## Pre-requisites
1. OpenShift 4.1 instance created via
    * RHPDS deployed "OCP and Container Storage for Admins"
    * AgnosticD deployed OCP4 environment
    * [AWS deployed](./OpenShiftInstaller.md) vanilla environment via openshift-installer
1. Updated `ocp.env` with login details for above environment
    * use `ocp.env.sample` as an example of the data required
1. Valid `3scale.env` for the 3scale deployment 
1. Valid `amps3.yml` for the 3scale deployment
1. Admin OpenShift [username/password](./OpenShiftUserAuth.md)


=======

## Stage 0 - Validate Environment
Copy `ocp.env.sample` to `ocp.env` and update with your lab/admin/kubeadmin credentials

Then validate that our OCP credentials are correct and copies any other GIT repos
```
./setup.sh
```

### Optional
copy your ssh-key to the bastion host
```
ssh-copy-id <lab-user> <bastion node>
```

### Recommended
Switch from using the **kubeadmin** default user to an **admin** user setup
via an [OpenShift Auth Provider](./OpenShiftUserAuth.md)
```
./ocp_htpass.sh
```

Update ocp.env to use
```
OCP_USER=admin
OCP_PASS=<your new password>
```

Re-Run Setup to confirm our login works and your user is **admin**
``` 
./setup.sh
```

## Stage 1 - Deploy Storage
This takes approx 20 minutes
```
./deploy_ocs.sh base
```
You’ll need to press CTRL-C a couple of times once some of the pods have started


## Stage 2 - Deploy 3 Scale
This can also take about 20 minutes but the Istio deployment can happen in parallel.
```
./3scale.sh
```

## Stage 3 - Deploy Istio
```
./service_mesh.sh
```

## Stage 4 - Deploy Application
This requires Istio / Service Mesh to be deployed
```
./productinfo_app.sh
```

## Stage 5 - Configure environment for Couchbase
```
./couchbase.sh setup
```

# Clean up Deployment
Ideally we recommend you start with a new OpenShift cluster cleaning up
all of the services can be difficult, particularly the storgae deployed
on physical nodes

We also recommend you remove all services that are consuming storage before
removing the ocs components

Remove Couchbase Operator and Instances
```
./couchbase.sh delete
```

Remove 3scale
```
./cleanup_3scale.sh
```

Remove Istio / Service Mesh
```
./cleanup_service_mesh.sh
```

Remove the Product info app
```
./cleanup_productinfo.sh
```

Confirm all storage PVs have been remove
```
oc get pvc --all-namespaces 
oc get pv --all-namespaces 

# If there are any still present
#  NOTE - this might take some time to return
oc delete pvc --all-namespaces
oc delete pv --all-namespaces

# And confirm we're clean
oc get pv
```

Remove the storage nodes and rook-ceph
```
./cleanup_ocs.sh
```

# Known Issues
## Cannot deploy cleanly onto vanilla OCP4 Workshop environment from OPEN / RHPDS

* Potential permission issues?
    * opentlc-mgr doesn't appear to have the same permissions as kubeadmin
    * This is an admin user so deployment **should** work
* Only one worker is initially deployed
    * https://docs.openshift.com/container-platform/4.1/machine_management/manually-scaling-machineset.html
    * Example fix below
```
https://docs.openshift.com/container-platform/4.1/machine_management/manually-scaling-machineset.html
oc get machinesets -n openshift-machine-api

oc scale --replicas=1 machineset cluster-<GUID>-worker-us-east-1b -n openshift-machine-api
oc scale --replicas=1 machineset cluster-<GUID>-worker-us-east-1c -n openshift-machine-api

# Wait for them to become Ready
oc get machinesets -n openshift-machine-api
```

* Error creating  instances
```
I0909 03:18:28.879446       1 controller.go:297] MachineSet "cluster-akl-849b-dsn89-workerocs-us-east-2a" in namespace "openshift-machine-api" doesn't specify "cluster.k8s.io/cluster-name" label, assuming nil cluster
```

* Looks like we can't find our subnet for deployment
```
E0909 03:58:55.710944       1 actuator.go:104] Machine error: error launching instance: error getting subnet IDs: no subnet IDs were found,
E0909 03:58:55.710973       1 actuator.go:113] error creating machine: error launching instance: error getting subnet IDs: no subnet IDs were found,
```

* Appears we were deploying in the wrong region - change to us-east-1

* New error appears to be due to AMI access issues in us-east-1
```
E0909 04:25:51.837081       1 instances.go:191] Error describing AMI: InvalidAMIID.NotFound: The image id '[ami-0eef624367320ec26]' does not exist
	status code: 400, request id: 7f5f6378-e23f-4551-a501-a0206176e1cb
```
* escallate to Red Hat RHPDS Team

# APAC Red Hat Forum OpenShift Demos
Demo deployment scripts for Red Hat APAC Forum 2019

The Demo covers a broad range of Red Hat technologies running on 
Red Hat OpenShift Container Platform 4.x

* [OpenShift Container Storage](./OpenShiftContainerStorage.md)
* 3Scale (2.5 at present)
* Istio Service Mesh
* Kubernetes Operators - via Couchbase
* [Quarkus and Java](./Quarkus.md)
* [Codeready Workspaces](./CodeReadyWorkspaces.md)

Currently the deployment needs to be staged due to pod/container dependencies, and is dependent on a numer of [External Git Respositories](./ExternalGitRepos.md)

The scripts make use of “watch” to keep an eye on the environment and you’ll have to occasionally press CTRL-C to continue.

## Pre-requisites
1. OpenShift 4.1 instance created via
    * RHPDS deployed "OCP and Container Storage for Admins"
    * AgnosticD deployed OCP4 environment
    * [AWS deployed](./OpenShiftInstaller.md) vanilla environment via openshift-installer
1. Updated `ocp.env` with login details for above environment
    * use `ocp.env.sample` as an example of the data required
1. Valid `3scale.2.5.env` for the 3scale 2.5 deployment 
1. Valid `amps3.25.yml` for the 3scale 2.5 deployment
1. Valid `ocpfuse74.env` for the fuse deployment
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

### Stage 0.1 - enable the admin user
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

### Stage 0.2 - Fix up the certified-operators image
We've got an issue with the default certified operators image if we're running
OpenShift 4.1.3
``` 
./operator_fix.sh
```


## Stage 1 - Deploy Storage
This takes approx 20 minutes
```
./deploy_ocs.sh base
```
You’ll need to press CTRL-C a couple of times once some of the pods have started


## Stage 2a - Deploy all the RH Forum demo workloads and apps
This can also take about 40 minutes - and you'll need to interact occasionally
```
./deploy_workloads.sh setup
```

**Remaining deployment steps can then be ignored**


## Stage 2b- Deploy 3 Scale
This can also take about 20 minutes but the Istio deployment can happen in parallel.
```
./3scale_25.sh
```

## Stage 3 - Deploy Istio
```
./service_mesh.sh setup
```

## Stage 4 - Deploy Application
This requires Istio / Service Mesh to be deployed
```
./productinfo_app.sh setup
```

## Stage 5 - Configure environment for Couchbase
```
./couchbase.sh setup
```

## Stage 6a - Create additional worker nodes required for [Quarkus/Java](./Quarkus.md) Demo
```
# Create additional machine-sets for quarkus and java
./scale_workers.sh quarkus
./scale_workers.sh java

# Start the new machines and monitor their creation
./scale_workers.sh start
./scale_workers.sh status
```

## Stage 6b - Configure environment for Quarkus and Java Demo
Note we need to taint the workers to avoid other pods being scheduled
```
./quarkus.sh taint
./quarkus.sh setup
```

## Stage 7 - Deploy Fuse 7.4 and BigPharm Demo Code
```
./fuse74.sh setup
./bigpharmfusedeploy.sh setup
```

## Stage 8 Deploy CRW and the sample workspaces
```
./deploy_crw_ocp4.sh -d -p=codeready-workspaces
./crw_imagestream.sh
./crw_create_quarkus_workspace.sh
./crw_create_nodejs_workspace.sh

```

## Then output the tips to resolve the [CRW Load Balancer](./CodeReadyWorkspaces.md) issue
```
./crw_lb_timeout.sh
```


# Clean up Deployment
Ideally we recommend you start with a new OpenShift cluster cleaning up
all of the services can be difficult, particularly the storgae deployed
on physical nodes

We also recommend you remove all services that are consuming storage before
removing the ocs components

Remove the Code Ready Workspaces - this can take a while
```
./cleanup_crw_ocp4.sh -c -p=codeready-workspaces
```

Remove the bigpharm app - Can't currently clean up the Fuse deployment
```
./bigpharmfusedeploy.sh cleanup
```

Remove the Quarkus and Java environment
```
./quarkus.sh delete
./quarkus.sh untaint
```

Delete the additional worker nodes created for  for [Quarkus/Java](./Quarkus.md) Demo
including any custom workload nodes
```
./scale_workers.sh stop
./scale_workers.sh down
./scale_workers.sh status
```

Remove Couchbase Operator and Instances
```
./couchbase.sh delete
```

Remove the Product info app
```
./productinfo_app.sh cleanup
```

Remove Istio / Service Mesh
```
./service_mesh.sh delete
```

Remove 3scale
```
./3scale_25.sh cleanup
```

Confirm all storage PVs have been removed 
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
## Storage issues for Code Ready Workspaces demo
This usually mans that CRW was deployed to use the default Storage Class which is Ceph RBD (RWO). We need to  update the config to utilise out CephFS (RWX) Storage class

Default Config map for che
```
CHE_INFRA_KUBERNETES_PVC_STORAGE__CLASS__NAME: ""
```

To check your config
```
oc project codeready-workspaces
oc get cm che -o yaml | grep PVC
```


Update configuration
```
CHE_INFRA_KUBERNETES_PVC_STORAGE__CLASS__NAME: "csi-cephfs"
```


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

# apac_rh_forum_19
Demo deployment scripts for Red Hat APAC Forum 2019

Currently the deployment needs to be staged due to pod/container dependencies.

The scripts make use of “watch” to keep an eye on the environment and you’ll have to occasionally press CTRL-C to continue.

## Pre-requisites
1. RHPDS deployed "OCP and Container Storage for Admins"
1. Updated `ocp.env` with login details for above environment
    * use `ocp.env.sample` as an example of the data required
1. Valid `3scale.env` for the 3scale deployment 
1. Valid `amps3.yml` for the 3scale deployment


## Stage 0 - Validate Environment
Copy `ocp.env.sample` to `ocp.env` and update with your lab credentials

Then validate that our OCP credentials are correct and copies any other GIT repos
```
./setup.sh
```

### Optional
copy your ssh-key to the bastion host
```
ssh-copy-id <lab-user> <bastion node>
```

## Stage 1 - Deploy Storage
This takes approx 20 minutes
```
./deploy_ocs.sh
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
./booking_app.sh
```

# Clean up Deployment
Ideally we recommend you start with a new OpenShift cluster cleaning up
all of the services can be difficult, particularly the storgae deployed
on physical nodes

We also recommend you remove all services that are consuming storage before
removing the ocs components


Remove Istio / Service Mesh
```
./cleanup_service_mesh.sh
```


Confirm all storage PVs have been remove
```
oc get pv

# If there are any still present
#  NOTE - this might take some time to return
oc delete pv --all

# And confirm we're clean
oc get pv
```

Remove the storage nodes and rook-ceph
```
./cleanup_ocs.sh
```

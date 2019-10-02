# OpenShift Container Storage - OCS

The demo includes Red Hat's OpenShift Container Storage technology to enable
the rapid delivery of stable dynamic storage for the demo workloads.

Currently the demos that make use of OCS are

* 3Scale 
    * mysql
    * redis
* Couchbase
* [Codeready Workspaces](./CodeReadyWorkspaces.md)
    * RWO block for psql
    * RWX file for shared workspaces


## OCS Technologies

OCS 4.x is made up of a number of technology components

* Rook.io
* Ceph
* NooBaa

For the purposes of this environment we're currently only using Rook and Ceph,
and ahead of the OCS 4.2 GA we're using the upstream Rook 1.1 codebase.

## Deployment Architecture

The OCS [deployment script](../deploy_ocs.sh) is currently based on our
**OCP and Container Storage for Admins** demo environment. This leverages
a machine set to deploy 3 additional AWS hosted m5d.large instances with
73GB of NVMe disk. These disks are leveraged to create a single Ceph enviroment
for block (RWO) and file (RWX) storage.

A typical Rook-Ceph deployment look like

![Rook Ceph Architecture](https://raw.githubusercontent.com/openshift/openshift-cns-testdrive/ocp4-prod/labguide/images/rook_diagram_4.png)

## Deployment Approach
Our deployment script can deploy all of the required components for our demos via a single command
```
./deploy_ocs base
```

This can be broken down into the following individual steps
```
# Provision the machine set and associated AWS Instances
./deploy_ocs storage

# Install the rook operator
./deploy_ocs rook

# Configure Ceph for RBD (RWO) storage and enable as the default storage class
./deploy_ocs rbd

# Configure Ceph for Cephfs (RWX) storage 
./deploy_ocs cephfs
```

Optionally you can also deploy Cephs Object storage support as we don't currently
have NooBaa integrated as part of this demo
```
./deploy_ocs object
```

## Additional Storage Classes
Post deployment you should have two additional storage classes in addition
to the default gp2 AWS provisioner
```
oc get sc
NAME                        PROVISIONER                     AGE
csi-cephfs                  rook-ceph.cephfs.csi.ceph.com   14d
gp2                         kubernetes.io/aws-ebs           14d
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com      34m
```

## Alternative Approach
If you're using AgnosticD to deploy your OpenShift environment you can include the ceph role
which will provision a version of OCS that uses gp2 backed storage rather than NVMe backed
m5d.large instances

